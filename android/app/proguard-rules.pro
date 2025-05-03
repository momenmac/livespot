# Keep rules for BouncyCastle classes
-keep class org.bouncycastle.jsse.** { *; }
-keep class org.bouncycastle.jsse.provider.** { *; }

# Keep rules for Conscrypt classes
-keep class org.conscrypt.** { *; }

# Keep rules for OpenJSSE classes
-keep class org.openjsse.** { *; }

# General rules for OkHttp
-dontwarn okhttp3.internal.platform.**
-dontwarn org.bouncycastle.**
-dontwarn org.conscrypt.**
-dontwarn org.openjsse.**
