/// Public backend settings (publishable values only — same as the web app's VITE_* vars).
class AppConfig {
  static const supabaseUrl = 'https://qhcpbemzxzvdsucqeobc.supabase.co';
  static const supabasePublishableKey = 'sb_publishable_JezI_rCrzC_OY7ZLDzEThw_k4S320A2';
  static const supportEmail = 'hello@mimi.app';

  /// Web app origin for email links (confirm / reset password). Switch to the published
  /// domain once the web app is published.
  static const webOrigin = 'https://id-preview--64461c5f-7236-4669-9a4d-08d2d42916f1.lovable.app';
}
