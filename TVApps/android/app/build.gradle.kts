plugins { id("com.android.application") }

android {
    namespace = "com.gametranslator.tv"
    compileSdk = 36

    defaultConfig {
        applicationId = "com.gametranslator.tv"
        minSdk = 24
        targetSdk = 35
        versionCode = 1
        versionName = "1.0"
    }
}

dependencies { testImplementation("junit:junit:4.13.2") }
