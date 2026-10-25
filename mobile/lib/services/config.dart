/// Public backend settings (publishable values only — same as the web app's VITE_* vars).
class AppConfig {
  static const googleWebClientId = '275836414743-lp23tluqq1f9ojm635ebkjdgjuukocdd.apps.googleusercontent.com';
  static const googleIosClientId = '275836414743-leolu0dp0j8v0jatevcqq327073ssd3b.apps.googleusercontent.com';
  static const googleAndroidClientId = '275836414743-p6pcqt7481289gp8enl5poa6prnueg8t.apps.googleusercontent.com';
  static const supabaseUrl = 'https://gcoboyhfhadivheoilxp.supabase.co';
  static const supabasePublishableKey = 'sb_publishable_JOxUNeytyMgxSTRYr6dRng_9B-WAYZW';

  /// Published web app origin for email links (confirm / reset password). Never the preview
  /// URL: that one needs a Lovable login, so learners could not open the link.
  static const webOrigin = 'https://kiku-clip-word-garden.lovable.app';

  /// Published web app (stable URL) that serves online features such as Ask Kizuki.
  /// The preview URL needs a Lovable login, so the phone app always talks to the published one.
  static const apiOrigin = 'https://kiku-clip-word-garden.lovable.app';
}
