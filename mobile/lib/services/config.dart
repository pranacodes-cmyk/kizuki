/// Public backend settings (publishable values only — same as the web app's VITE_* vars).
class AppConfig {
  static const supabaseUrl = 'https://qhcpbemzxzvdsucqeobc.supabase.co';
  static const supabasePublishableKey = 'sb_publishable_JezI_rCrzC_OY7ZLDzEThw_k4S320A2';

  /// Published web app origin for email links (confirm / reset password). Never the preview
  /// URL: that one needs a Lovable login, so learners could not open the link.
  static const webOrigin = 'https://kiku-clip-word-garden.lovable.app';

  /// Published web app (stable URL) that serves online features such as Ask Kizuki.
  /// The preview URL needs a Lovable login, so the phone app always talks to the published one.
  static const apiOrigin = 'https://kiku-clip-word-garden.lovable.app';
}
