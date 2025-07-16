package com.knime.old;

import com.knime.old.MyClass;
import com.knime.old.Container.NestedHelper;

public class OldName {
    
    private MyClass myClass;
    private NestedHelper helper;
    
    public OldName() {
        this.myClass = new MyClass();
        this.helper = new NestedHelper();
    }
    
    public void useClasses() {
        MyClass local = new MyClass();
        NestedHelper localHelper = new NestedHelper();
        
        // Method calls
        local.someMethod();
        localHelper.helperMethod();
    }
}