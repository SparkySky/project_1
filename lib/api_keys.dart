// .gitignore already
const String GEMINI_API_KEY = String.fromEnvironment(
  'Backupkeyhere',
  defaultValue: '', // A fallback, but the goal is to always use the --dart-define flag.
);
