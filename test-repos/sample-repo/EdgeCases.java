package com.example.edge;

import com.knime.old.MyClass;
import com.knime.old.OldName;
import com.knime.old.StandaloneClass;

/**
 * This file tests edge cases where capture groups are important
 * to avoid incorrect replacements.
 */
public class EdgeCases {
    
    // Test cases where class names appear at word boundaries
    MyClass field1;           // Start of line
    private MyClass field2;   // After space
    MyClass[] arrayField;     // Before bracket
    List<MyClass> listField;  // In generics
    Map<String,MyClass> map;  // After comma (no space)
    
    // Method names that contain class names - should NOT be renamed
    public void createMyClassInstance() {
        // This method name contains "MyClass" but shouldn't be renamed
    }
    
    public void oldNameProcessor() {
        // This method name contains "OldName" but shouldn't be renamed  
    }
    
    // Variable names that contain class names - should NOT be renamed
    private String myClassFactory;
    private int oldNameCounter;
    private boolean standaloneClassEnabled;
    
    // Test punctuation boundaries
    public void testPunctuation() {
        MyClass a, b, c;          // Comma separated
        MyClass obj = new MyClass(); // Assignment
        if (obj instanceof MyClass) {  // instanceof
            ((MyClass) obj).toString(); // Cast
        }
        
        // Function calls and method chaining
        process(new MyClass());
        MyClass.staticMethod();
        obj.method().process(MyClass.VALUE);
        
        // Array access and generics
        MyClass[][] matrix = new MyClass[5][5];
        List<MyClass[]> listOfArrays;
        Map<String, List<MyClass>> complexGeneric;
    }
    
    // Annotations and other contexts
    @SuppressWarnings("MyClass")  // Should this be renamed? Probably not in annotation values
    public MyClass annotatedMethod(@Param MyClass param) {
        return param;
    }
    
    // String literals and comments containing class names - SHOULD be renamed
    public void stringsAndComments() {
        String className = "MyClass";  // String literal - should be renamed
        String fullName = "com.knime.old.MyClass";  // FQN in string - should be renamed
        
        /* 
         * This comment mentions MyClass and OldName
         * and should be modified accordingly
         */
        
        // TODO: Refactor MyClass to use better patterns
        logger.info("Processing MyClass instance: " + obj);
    }
}

// Test class at end of file without trailing newline
class TestEndOfFile extends MyClass {
}