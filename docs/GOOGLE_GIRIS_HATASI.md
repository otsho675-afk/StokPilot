# StokPilot Google Giris [16] Hatasi

GoogleSignInExceptionCode.canceled + [16] Account reauth failed her zaman
kullanicinin girisi iptal ettigi anlamina gelmez. Android Credential Manager
bazen hatali OAuth yapilandirmasini da canceled olarak bildirir.

## 1. Yerel Firebase ve Gradle imzalarini incele

~~~powershell
cd C:\Users\HGDGFJr\StokPilot-GitHub
git pull --ff-only origin main
.\scripts\check_google_signin_windows.ps1
~~~

Betiğin ciktisinda Firebase projesi stokpilot-5bd2e ve Android paket adi
com.yesildas.stokpilot olmali. debug varyantinin SHA-1 ve SHA-256
parmak izlerini not edin.

## 2. Firebase Console

1. Firebase Console -> Project settings -> Your apps -> Android uygulamasi
   com.yesildas.stokpilot. Gercek Gradle applicationId ile ayni olmali.
2. Add fingerprint ile debug SHA-1 ve SHA-256 degerlerini kaydedin.
3. Authentication -> Sign-in method -> Google -> Enable ve Save.
4. Yeni google-services.json dosyasini indirin ve android/app klasorune
   yerlestirin. Eski dosyayi degistirin. Firebase Android uygulamasi
   icin Web OAuth client_type 3 kaydini da kontrol edin.
5. flutter clean; flutter pub get; flutter run ile yeniden derleyin.

Google Play'den yuklenen uygulama icin App integrity -> App signing
SHA-1/SHA-256 parmak izleri de Firebase'e ayrica eklenmelidir.

## 3. Istege bagli acik Web OAuth istemci kimligi

Eger android/app/google-services.json Web OAuth istemcisi icermiyorsa
Google Cloud Console -> APIs & Services -> Credentials -> OAuth 2.0
Client IDs -> Web application kimligini dogrulayin.

~~~powershell
flutter run --dart-define="GOOGLE_WEB_CLIENT_ID=YOUR_WEB_CLIENT_ID.apps.googleusercontent.com"
~~~

Bunun Web OAuth istemci kimligi olmasi gerekir, Android istemcisi degil.
Yanlis SHA veya paket adini bu parametre tek basina duzeltmez.

## 4. Devam ediyorsa

Google Play Hizmetlerini guncelleyin; baska hesap ve mumkunse farkli
Android cihazinda deneyin. Android surumu, emulator/fiziksel cihaz
ve uygulamanin yukleme kaynagini karsilastirin.
Misafir hesap verileri icin uygulamayi silmeyin.

Kaynak: https://pub.dev/packages/google_sign_in_android
