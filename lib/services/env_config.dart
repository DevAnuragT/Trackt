import 'package:flutter_dotenv/flutter_dotenv.dart';

class EnvConfig {
  static String env = 'dev';

  static Future<void> load() async {
    // Pick env from --dart-define=ENV=dev|stg|prod
    const defineEnv = String.fromEnvironment('ENV', defaultValue: 'dev');
    env = ['dev', 'stg', 'prod'].contains(defineEnv) ? defineEnv : 'dev';
    final fileName = env == 'prod'
        ? '.env.prod'
        : env == 'stg'
            ? '.env.stg'
            : '.env.dev';
    try {
      await dotenv.load(fileName: fileName, mergeWith: {'APP_ENV': env});
    } catch (_) {
      // If asset isn't packaged (e.g., CI or clean clone), proceed with defaults only.
      // Accessors below use maybeGet with sensible fallbacks.
    }
  }

  static String get appEnv {
    // Be resilient in tests or early app boot when dotenv isn't loaded yet.
    try {
      return dotenv.maybeGet('APP_ENV') ?? env;
    } catch (_) {
      return env;
    }
  }

  static bool get isProd => appEnv == 'prod';
  static bool get isStg => appEnv == 'stg';
  static bool get isDev => appEnv == 'dev';

  // Additional app settings
  static String get mapProvider => dotenv.maybeGet('MAP_PROVIDER') ?? 'mapbox';
  static String get mapboxToken => dotenv.maybeGet('MAPBOX_ACCESS_TOKEN') ?? '';

  // Supabase
  static String? get supabaseUrl => dotenv.maybeGet('SUPABASE_URL');
  static String? get supabaseAnonKey => dotenv.maybeGet('SUPABASE_ANON_KEY');

  // Google Sign-In (native)
  static String? get googleServerClientId => dotenv.maybeGet('GOOGLE_SERVER_CLIENT_ID');

  // Monad Testnet Web3 (Chain ID 10143)
  static String? _maybe(String key) {
    try {
      return dotenv.maybeGet(key);
    } catch (_) {
      return null;
    }
  }

  static String get monadRpcUrl =>
      _maybe('MONAD_RPC_URL') ?? 'https://testnet-rpc.monad.xyz';
  static int get monadChainId => int.tryParse(_maybe('MONAD_CHAIN_ID') ?? '') ?? 10143;

  // Deployed contract addresses (supplied by teammate once verified on Monad Testnet).
  // Empty until deployment; MonadService degrades to local proof when unset.
  static String get monadTerritoryContract =>
      _maybe('MONAD_TERRITORY_CONTRACT') ?? '';
  static String get monadTokenContract => _maybe('MONAD_TOKEN_CONTRACT') ?? '';
}
