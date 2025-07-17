package com.example.test;

import com.knime.old.MyClass;
import com.knime.old.OldName;
import com.knime.old.OuterClass.InnerClass;
import com.knime.old.StandaloneClass;
import com.knime.old.Container.NestedHelper;
import static com.knime.old.Container.NestedHelper.staticMethod;

public class TestFile {
    
    public void testMethod() {
        MyClass myClass = new MyClass();
        OldName oldName = new OldName();
        InnerClass inner = new InnerClass();
        StandaloneClass standalone = new StandaloneClass();
        NestedHelper helper = new NestedHelper();
        
        // Static method call
        NestedHelper.staticMethod();
        staticMethod();
        
        // Type references
        MyClass[] array = new MyClass[10];
        List<OldName> list = new ArrayList<>();
        
        // Generic usage
        Map<String, InnerClass> map = new HashMap<>();
        Optional<StandaloneClass> optional = Optional.empty();
    }
    
    // Method parameter usage
    public void processData(MyClass data, OldName name) {
        // Method body
    }
    
    // Return type usage
    public InnerClass createInner() {
        return new InnerClass();
    }
    
    // Field declarations
    private MyClass fieldMyClass;
    private OldName fieldOldName;
    private InnerClass fieldInner;
    private StandaloneClass fieldStandalone;
    private NestedHelper fieldHelper;
}