package com.example.other;

import java.util.List;
import com.other.framework.SomeClass;
import com.different.package.DataHelper;

/**
 * This file contains classes that should NOT be renamed by our script.
 * It includes completely different class names that should remain unchanged.
 */
public class UntouchedFile {
    
    // These should NOT be changed - they are completely different classes
    private String description = "This is about some other classes";
    private String variable = "variable with different names";
    
    // Class names that are completely different
    private DataHelper helper;  // Should NOT be renamed (different class)
    private SuperName superObj;  // Should NOT be renamed (different class)
    
    public void methodWithDifferentNames() {
        // Method that mentions completely different class names
        // This comment mentions DataHelper and other classes
        String message = "Processing DataHelper instances"; // String containing different class name
        
        // Variables with different names
        String helperPrefix = "prefix";
        String nameSuffix = "suffix";
        
        // Method calls with different names  
        processData();  // Different method
        handleNames();  // Different method
    }
    
    private void processData() {
        // Different method name
    }
    
    private void handleNames() {
        // Different method name
    }
}

class SuperName {
    // A completely different class
}

class DataHelper {
    // A completely different class
}