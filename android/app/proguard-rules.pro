# Keep Isar classes
-keep class io.isar.** { *; }
-keep class isar.** { *; }

# Keep generated Isar classes
-keep class **.*Isar* { *; }
-keep class **.*Schema* { *; }

# Keep model classes used by Isar
-keep class **.models.** { *; }

# Keep native methods
-keepclasseswithmembernames class * {
    native <methods>;
}

# Prevent obfuscation of reflection-based code
-keepattributes *Annotation*
-keepattributes Signature
-keepattributes InnerClasses

# Keep Flutter classes
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Prevent crashes from method channel calls
-keep class ** {
    public <methods>;
}
