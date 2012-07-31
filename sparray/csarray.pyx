# cython: profile=False
from cython.operator cimport dereference as deref, preincrement as inc 
import numpy 
cimport numpy 
numpy.import_array()

cdef extern from "include/SparseMatrixExt.h":  
   cdef cppclass SparseMatrixExt[T]:  
      SparseMatrixExt() 
      SparseMatrixExt(SparseMatrixExt[T]) 
      SparseMatrixExt(int, int)
      int rows()
      int cols() 
      int size() 
      void insertVal(int, int, T) 
      int nonZeros()
      void nonZeroInds(int*, int*)
      T coeff(int, int)
      T sum()
      void slice(int*, int, int*, int, SparseMatrixExt[T]*) 
      void scalarMultiply(double)

cdef class csarray:
    cdef SparseMatrixExt[double] *thisPtr     
    def __cinit__(self, shape, dtype=numpy.float):
        """
        Create a new column major dynamic array. One can pass in a numpy 
        data type but the only option is numpy.float currently. 
        """
        if dtype==numpy.float: 
            self.thisPtr = new SparseMatrixExt[double](shape[0], shape[1]) 
        else: 
            raise ValueError("Unsupported dtype: " + str(dtype))
            
    def __dealloc__(self): 
        """
        Deallocate the SparseMatrixExt object.  
        """
        del self.thisPtr
        
    def __getNDim(self): 
        """
        Return the number of dimensions of this array. 
        """
        return 2 
        
    def __getShape(self):
        """
        Return the shape of this array (rows, cols)
        """
        return (self.thisPtr.rows(), self.thisPtr.cols())
        
    def __getSize(self): 
        """
        Return the size of this array, that is rows*cols 
        """
        return self.thisPtr.size()   
        
    def getnnz(self): 
        """
        Return the number of non-zero elements in the array 
        """
        return self.thisPtr.nonZeros()
        
    def __getDType(self): 
        """
        Get the dtype of this array. 
        """
        return numpy.float
        
    def __getitem__(self, inds):
        """
        Get a value or set of values from the array (denoted A). Currently 3 types of parameters 
        are supported. If i,j = inds are integers then the corresponding elements of the array 
        are returned. If i,j are both arrays of ints then we return the corresponding 
        values of A[i[k], j[k]] (note: i,j must be sorted in ascending order). If one of 
        i or j is a slice e.g. A[[1,2], :] then we return the submatrix corresponding to 
        the slice. 
        """        
        
        i, j = inds 
        
        if type(i) == numpy.ndarray and type(j) == numpy.ndarray: 
            return self.__adArraySlice(numpy.ascontiguousarray(i, dtype=numpy.int) , numpy.ascontiguousarray(j, dtype=numpy.int) )
        elif (type(i) == numpy.ndarray or type(i) == slice) and (type(j) == slice or type(j) == numpy.ndarray):
            indList = []            
            for k in range(len(inds)):  
                index = inds[k] 
                if type(index) == numpy.ndarray: 
                    indList.append(index) 
                elif type(index) == slice: 
                    if index.start == None: 
                        start = 0
                    else: 
                        start = index.start
                    if index.stop == None: 
                        stop = self.shape[k]
                    else:
                        stop = index.stop  
                    indArr = numpy.arange(start, stop)
                    indList.append(indArr)
            
            return self.subArray(indList[0], indList[1])
        else:
            i = int(i) 
            j = int(j)
            
            #Deal with negative indices
            if i<0: 
                i += self.thisPtr.rows()
            if j<0:
                j += self.thisPtr.cols()    

            if i < 0 or i>=self.thisPtr.rows(): 
                raise ValueError("Invalid row index " + str(i)) 
            if j < 0 or j>=self.thisPtr.cols(): 
                raise ValueError("Invalid col index " + str(j))      
            return self.thisPtr.coeff(i, j)            
    
    def __adArraySlice(self, numpy.ndarray[numpy.int_t, ndim=1, mode="c"] rowInds, numpy.ndarray[numpy.int_t, ndim=1, mode="c"] colInds): 
        """
        Array slicing where one passes two arrays of the same length and elements are picked 
        according to self[rowInds[i], colInds[i]). 
        """
        cdef int ix 
        cdef numpy.ndarray[numpy.float_t, ndim=1, mode="c"] result = numpy.zeros(rowInds.shape[0])
        
        if (rowInds >= self.shape[0]).any() or (colInds >= self.shape[1]).any(): 
            raise ValueError("Indices out of range")
        
        for ix in range(rowInds.shape[0]): 
                result[ix] = self.thisPtr.coeff(rowInds[ix], colInds[ix])
        return result
    
    def subArray(self, numpy.ndarray[numpy.int_t, ndim=1, mode="c"] rowInds, numpy.ndarray[numpy.int_t, ndim=1, mode="c"] colInds): 
        """
        Explicitly perform an array slice to return a submatrix with the given
        indices. Only works with ascending ordered indices. This is similar 
        to using numpy.ix_. 
        """
        cdef numpy.ndarray[int, ndim=1, mode="c"] rowIndsC 
        cdef numpy.ndarray[int, ndim=1, mode="c"] colIndsC 
        
        cdef csarray result = csarray((rowInds.shape[0], colInds.shape[0]))     
        
        rowIndsC = numpy.ascontiguousarray(rowInds, dtype=numpy.int32) 
        colIndsC = numpy.ascontiguousarray(colInds, dtype=numpy.int32) 
        
        if rowInds.shape[0] != 0 and colInds.shape[0] != 0: 
            self.thisPtr.slice(&rowIndsC[0], rowIndsC.shape[0], &colIndsC[0], colIndsC.shape[0], result.thisPtr) 
        return result 
        
    def nonzero(self): 
        """
        Return a tuple of arrays corresponding to nonzero elements. 
        """
        cdef numpy.ndarray[int, ndim=1, mode="c"] rowInds = numpy.zeros(self.getnnz(), dtype=numpy.int32) 
        cdef numpy.ndarray[int, ndim=1, mode="c"] colInds = numpy.zeros(self.getnnz(), dtype=numpy.int32)  
        
        if self.getnnz() != 0:
            self.thisPtr.nonZeroInds(&rowInds[0], &colInds[0])
        
        return (rowInds, colInds)
                    
    def __setitem__(self, inds, val):
        """
        Set elements of the array. If i,j = inds are integers then the corresponding 
        value in the array is set. 
        """
        i, j = inds 
        if type(i) == int and type(j) == int: 
            if i < 0 or i>=self.thisPtr.rows(): 
                raise ValueError("Invalid row index " + str(i)) 
            if j < 0 or j>=self.thisPtr.cols(): 
                raise ValueError("Invalid col index " + str(j))        
            
            self.thisPtr.insertVal(i, j, val) 
        elif type(i) == numpy.ndarray and type(j) == numpy.ndarray: 
            for ix in range(len(i)): 
                self.thisPtr.insertVal(i[ix], j[ix], val)  
    
    def put(self, double val, numpy.ndarray[numpy.int_t, ndim=1] rowInds not None , numpy.ndarray[numpy.int_t, ndim=1] colInds not None): 
        """
        Select rowInds 
        """
        cdef unsigned int ix 
        for ix in range(len(rowInds)): 
            self.thisPtr.insertVal(rowInds[ix], colInds[ix], val)

    def sum(self, axis=None): 
        """
        Sum all of the elements in this array. If one specifies an axis 
        then we sum along the axis. 
        """
        cdef numpy.ndarray[double, ndim=1, mode="c"] result    
        cdef numpy.ndarray[int, ndim=1, mode="c"] rowInds
        cdef numpy.ndarray[int, ndim=1, mode="c"] colInds
        cdef unsigned int i
        
        if axis==None: 
            scalarResult = 0 
            (rowInds, colInds) = self.nonzero()
            
            for i in range(rowInds.shape[0]): 
                scalarResult += self.thisPtr.coeff(rowInds[i], colInds[i])  
            
            return scalarResult
            #There seems to be a very temporamental problem with thisPtr.sum()
            #return self.thisPtr.sum()
        elif axis==0: 
            result = numpy.zeros(self.shape[1], dtype=numpy.float) 
            (rowInds, colInds) = self.nonzero()
            
            for i in range(rowInds.shape[0]): 
                result[colInds[i]] += self.thisPtr.coeff(rowInds[i], colInds[i])   
        elif axis==1: 
            result = numpy.zeros(self.shape[0], dtype=numpy.float) 
            (rowInds, colInds) = self.nonzero()
            
            for i in range(rowInds.shape[0]): 
                result[rowInds[i]] += self.thisPtr.coeff(rowInds[i], colInds[i])  
        else:
            raise ValueError("Invalid axis: " + str(axis))
            
        return result 
                
        
    def mean(self, axis=None): 
        """
        Find the mean value of this array. 
        """
        if self.thisPtr.size() != 0:
            if axis ==None: 
                return self.sum()/self.thisPtr.size()
            elif axis == 0: 
                return self.sum(0)/self.shape[0]
            elif axis == 1: 
                return self.sum(1)/self.shape[1]
        else: 
            return float("nan")
     
    def __str__(self): 
        """
        Return a string representation of the non-zero elements of the array. 
        """
        outputStr = "csarray shape:" + str(self.shape) + " non-zeros:" + str(self.getnnz()) + "\n"
        (rowInds, colInds) = self.nonzero()
        vals = self[rowInds, colInds]
        
        for i in range(self.getnnz()): 
            outputStr += "(" + str(rowInds[i]) + ", " + str(colInds[i]) + ")" + " " + str(vals[i]) + "\n"
        
        return outputStr 
        
    def diag(self): 
        """
        Return a numpy array containing the diagonal entries of this matrix. If 
        the matrix is non-square then the diagonal array is the same size as the 
        smallest dimension. 
        """
        cdef unsigned int maxInd = min(self.shape[0], self.shape[1])
        cdef unsigned int i   
        cdef numpy.ndarray[numpy.float_t, ndim=1, mode="c"] result = numpy.zeros(maxInd)
        
        for i in range(maxInd): 
            result[i] = self.thisPtr.coeff(i, i)
            
        return result
        
    def trace(self): 
        """
        Returns the trace of the array which is simply the sum of the diagonal 
        entries. 
        """
        return self.diag().sum()
         
    def __mul__(self, double x):
        """
        Return a new array multiplied by a scalar value x. 
        """
        cdef csarray result = self.copy() 
        result.thisPtr.scalarMultiply(x)
        return result 
        
    def copy(self): 
        """
        Return a copied version of this array. 
        """
        cdef csarray result = csarray(self.shape)
        del result.thisPtr
        result.thisPtr = new SparseMatrixExt[double](deref(self.thisPtr))
        return result 
        
    def toarray(self): 
        """
        Convert this sparse matrix into a numpy array. 
        """
        cdef numpy.ndarray[double, ndim=2, mode="c"] result = numpy.zeros(self.shape, numpy.float)
        cdef numpy.ndarray[int, ndim=1, mode="c"] rowInds
        cdef numpy.ndarray[int, ndim=1, mode="c"] colInds
        cdef unsigned int i
        
        (rowInds, colInds) = self.nonzero()
            
        for i in range(rowInds.shape[0]): 
            result[rowInds[i], colInds[i]] += self.thisPtr.coeff(rowInds[i], colInds[i])   
            
        return result 
        
        
    def min(self): 
        """
        Find the minimum element of this array. 
        """
        cdef numpy.ndarray[int, ndim=1, mode="c"] rowInds
        cdef numpy.ndarray[int, ndim=1, mode="c"] colInds
        cdef unsigned int i
        cdef double minVal = float("inf")
        
        if self.size == 0: 
            minVal = float("nan")
        elif self.getnnz() != self.size: 
            minVal = 0 
        
        (rowInds, colInds) = self.nonzero()
            
        for i in range(rowInds.shape[0]): 
            if self.thisPtr.coeff(rowInds[i], colInds[i]) < minVal: 
                minVal = self.thisPtr.coeff(rowInds[i], colInds[i])
            
        return minVal 
        
    def max(self): 
        """
        Find the maximum element of this array. 
        """
        cdef numpy.ndarray[int, ndim=1, mode="c"] rowInds
        cdef numpy.ndarray[int, ndim=1, mode="c"] colInds
        cdef unsigned int i
        cdef double maxVal = -float("inf")
        
        if self.size == 0: 
            maxVal = float("nan")
        elif self.getnnz() != self.size: 
            maxVal = 0 
        
        (rowInds, colInds) = self.nonzero()
            
        for i in range(rowInds.shape[0]): 
            if self.thisPtr.coeff(rowInds[i], colInds[i]) > maxVal: 
                maxVal = self.thisPtr.coeff(rowInds[i], colInds[i])
            
        return maxVal 
        
    def var(self): 
        """
        Return the variance of the elements of this array. 
        """
        cdef double mean = self.mean() 
        cdef numpy.ndarray[int, ndim=1, mode="c"] rowInds
        cdef numpy.ndarray[int, ndim=1, mode="c"] colInds
        cdef unsigned int i
        cdef double result = 0
        
        if self.size == 0: 
            result = float("nan")
        
        (rowInds, colInds) = self.nonzero()
            
        for i in range(rowInds.shape[0]): 
            result += (self.thisPtr.coeff(rowInds[i], colInds[i]) - mean)**2
        
        result += (self.size - self.getnnz())*mean**2
        result /= self.size
            
        return result 
    
    def std(self): 
        """
        Return the standard deviation of the array elements. 
        """
        return numpy.sqrt(self.var())
        
    def __abs__(self): 
        """
        Return a matrix whose elements are the absolute values of this array. 
        """
        cdef csarray result = csarray(self.shape)
        cdef numpy.ndarray[int, ndim=1, mode="c"] rowInds
        cdef numpy.ndarray[int, ndim=1, mode="c"] colInds
        cdef unsigned int i
        
        (rowInds, colInds) = self.nonzero()
            
        for i in range(rowInds.shape[0]): 
            result.thisPtr.insertVal(rowInds[i], colInds[i], abs(self.thisPtr.coeff(rowInds[i], colInds[i])))
            
        return result  
    
    def __neg__(self): 
        """
        Return the negation of this array. 
        """
        cdef csarray result = csarray(self.shape)
        cdef numpy.ndarray[int, ndim=1, mode="c"] rowInds
        cdef numpy.ndarray[int, ndim=1, mode="c"] colInds
        cdef unsigned int i
        
        (rowInds, colInds) = self.nonzero()
            
        for i in range(rowInds.shape[0]): 
            result.thisPtr.insertVal(rowInds[i], colInds[i], -self.thisPtr.coeff(rowInds[i], colInds[i]))
            
        return result 
    

    def __add__(self, csarray A): 
        """
        Add two matrices together. 
        """
        cdef csarray result = self.copy()
        cdef numpy.ndarray[int, ndim=1, mode="c"] rowInds
        cdef numpy.ndarray[int, ndim=1, mode="c"] colInds
        cdef unsigned int i
        
        (rowInds, colInds) = A.nonzero()
            
        for i in range(rowInds.shape[0]): 
            result.thisPtr.insertVal(rowInds[i], colInds[i], result.thisPtr.coeff(rowInds[i], colInds[i]) + A.thisPtr.coeff(rowInds[i], colInds[i]))
            
        return result     
        
    def __sub__(self, csarray A): 
        """
        Subtract one matrix from another.  
        """
        cdef csarray result = self.copy()
        cdef numpy.ndarray[int, ndim=1, mode="c"] rowInds
        cdef numpy.ndarray[int, ndim=1, mode="c"] colInds
        cdef unsigned int i
        
        (rowInds, colInds) = A.nonzero()
            
        for i in range(rowInds.shape[0]): 
            result.thisPtr.insertVal(rowInds[i], colInds[i], result.thisPtr.coeff(rowInds[i], colInds[i]) - A.thisPtr.coeff(rowInds[i], colInds[i]))
            
        return result 
     
    def hadamard(self, csarray A): 
        """
        Find the element-wise matrix (hadamard) product. 
        """
        cdef csarray result = csarray(A.shape)
        cdef numpy.ndarray[int, ndim=1, mode="c"] rowInds
        cdef numpy.ndarray[int, ndim=1, mode="c"] colInds
        cdef unsigned int i
        
        if A.getnnz() < self.getnnz(): 
            (rowInds, colInds) = A.nonzero()
        else: 
            (rowInds, colInds) = self.nonzero()
            
        for i in range(rowInds.shape[0]): 
            result.thisPtr.insertVal(rowInds[i], colInds[i], self.thisPtr.coeff(rowInds[i], colInds[i]) * A.thisPtr.coeff(rowInds[i], colInds[i]))
            
        return result 
        
        
    
    shape = property(__getShape)
    size = property(__getSize)
    ndim = property(__getNDim)
    dtype = property(__getDType)

    
