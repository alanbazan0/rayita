# Reglas de R8 para Rayita. El plugin de Flutter ya agrega las suyas (motor y plugins);
# aquí solo se evitan avisos por clases opcionales que el motor menciona.

# Instalación diferida de componentes (Play Core): Rayita no la usa.
-dontwarn com.google.android.play.core.**
-dontwarn io.flutter.embedding.engine.deferredcomponents.**

# Para que los reportes de fallos conserven número de línea y archivo.
-keepattributes SourceFile,LineNumberTable
-renamesourcefileattribute SourceFile
