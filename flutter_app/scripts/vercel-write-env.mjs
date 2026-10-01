// Vercel build step for the prebuilt Flutter Web bundle in web_build.
//
// The app reads its public config from the bundled asset `assets/.env`
// (flutter_dotenv). That file is deliberately NOT committed to Git, so on
// Vercel this script generates it from the project's Environment Variables
// right before the static files are served.
//
// Only the three public values the web app needs are written (Supabase URL,
// Supabase ANON key, API base URL). Nothing else from the environment —
// and in particular no service-role key — can end up in the bundle.
import { existsSync, writeFileSync } from 'node:fs';
import { join } from 'node:path';

const outputDir = process.argv[2] ?? 'web_build';
const required = ['SUPABASE_URL', 'SUPABASE_ANON_KEY', 'API_BASE_URL'];

if (!existsSync(join(outputDir, 'index.html'))) {
  console.error(`No Flutter Web build found at ${outputDir}/index.html — commit web_build.`);
  process.exit(1);
}

const missing = required.filter((k) => !process.env[k]?.trim());
if (missing.length > 0) {
  console.error(`Missing Vercel Environment Variables: ${missing.join(', ')}`);
  process.exit(1);
}

const values = Object.fromEntries(required.map((k) => [k, process.env[k].trim()]));
if (/service[_-]?role/i.test(values.SUPABASE_ANON_KEY) || values.SUPABASE_ANON_KEY === process.env.SUPABASE_SERVICE_ROLE_KEY) {
  console.error('SUPABASE_ANON_KEY must be the public anon key, never the service-role key.');
  process.exit(1);
}

const contents = required.map((k) => `${k}=${values[k]}`).join('\n') + '\n';
writeFileSync(join(outputDir, 'assets', '.env'), contents);
console.log(`Wrote ${outputDir}/assets/.env with: ${required.join(', ')}`);
