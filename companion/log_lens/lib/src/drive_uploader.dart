/// Handles uploading captured log files to the user's Google Drive so they
/// can be picked up remotely (e.g. read directly by an AI assistant via the
/// Drive API) without any manual transfer step.
///
/// This is a stub: real automatic uploads require Google Sign-In + Drive API
/// OAuth credentials, which need a one-time setup in Google Cloud Console
/// (create project → enable Drive API → OAuth client ID for Android, with the
/// app's SHA-1 signing fingerprint registered). Once that's done, replace the
/// body of [signIn] / [uploadLogFile] with calls into `google_sign_in` and
/// `googleapis`'s `drive.v3` client.
class DriveUploader {
  bool _signedIn = false;

  bool get isSignedIn => _signedIn;

  /// Prompts the user to sign in with Google and grants Drive file access.
  Future<bool> signIn() async {
    // TODO: wire up google_sign_in with the `drive.file` scope once OAuth
    // client credentials are configured for this app.
    _signedIn = false;
    return _signedIn;
  }

  Future<void> signOut() async {
    _signedIn = false;
  }

  /// Uploads [content] as a text file named [fileName] to a `LogLens` folder
  /// in the user's Drive, creating the folder on first use.
  Future<Uri?> uploadLogFile({required String fileName, required String content}) async {
    if (!_signedIn) {
      throw StateError('Sign in to Google Drive before uploading.');
    }
    // TODO: use drive.FilesResource.create with the `drive.file` scope to
    // upload `content` and return a shareable link.
    return null;
  }
}
