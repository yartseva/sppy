import logging
import sys
import unittest
import numpy

from sparray.csr_array import csr_array 

class map_array_test(unittest.TestCase):
    def setUp(self):
        logging.basicConfig(stream=sys.stdout, level=logging.DEBUG)
        
        self.A = csr_array((5, 5))
        #self.A[0, 1] = 1 
        #self.A[1, 1] = 2 
        #self.A[2, 1] = 5 
        
        
    def testInit(self): 
        A = csr_array((5, 7))
        #A[0, 1] = 1 
        
        self.assertEquals(A.shape, (5, 7))
        
        A = csr_array((1, 1))
        self.assertEquals(A.shape, (1, 1))
        
        A = csr_array((1, 0))
        self.assertEquals(A.shape, (1, 0))
        
        A = csr_array((0, 0))
        self.assertEquals(A.shape, (0, 0))
        
    def testNDim(self): 
        A = csr_array((5, 7))
        self.assertEquals(A.ndim, 2)
        
    def testGetnnz(self): 
       A = csr_array((5, 7))
       A[0, 0] = 1.0
       
       self.assertEquals(A.getnnz(), 1)
       
       A[2, 1] = 1.0
       self.assertEquals(A.getnnz(), 2)
       
       A[2, 5] = 1.0
       A[3, 5] = 1.0
       self.assertEquals(A.getnnz(), 4)
       
       A[4, 4] = 0.0
       self.assertEquals(A.getnnz(), 5)
    
    @unittest.skip("")
    def testSetItem(self):
        nrow = 5 
        ncol = 7
        A = csr_array((nrow, ncol), 10)
        A[0, 1] = 1
        A[1, 3] = 5.2
        A[3, 3] = -0.2
        
        self.assertEquals(A[0, 1], 1)
        self.assertAlmostEquals(A[1, 3], 5.2, 5)
        self.assertAlmostEquals(A[3, 3], -0.2)
        
        for i in range(nrow): 
            for j in range(ncol): 
                if (i, j) != (0, 1) and (i, j) != (1, 3) and (i, j) != (3, 3): 
                    self.assertEquals(A[i, j], 0)
        
        try: 
            A[20, 0] = 1
            self.fail()
        except ValueError: 
            pass 
        
        try: 
            A[0, 20] = 1
            self.fail()
        except ValueError: 
            pass 

    @unittest.skip("")
    def testAdd(self): 
        self.B = csr_array((5, 5), 10)
        self.B[0, 1] = 1 
        self.B[1, 1] = 2 
        self.B[2, 2] = 5 
        
        C = self.B.add(self.A)
        
        print(C)
        print(self.B)
        print(self.A)

if __name__ == "__main__":
    #import sys;sys.argv = ['', 'Test.testName']
    unittest.main()
    
    