// Dream Space Supabase browser configuration.
// The publishable key is safe to expose when Row Level Security is correctly configured.
const DS_SUPABASE_URL = "https://kctgrsqxkflbqihctmor.supabase.co";
const DS_SUPABASE_KEY = "sb_publishable_s0xjRSwmgD-dhcqOh9CbWw_rXxdnXzW";
if (!window.supabase) {
  console.error("Supabase library did not load.");
} else {
  window.dsSupabase = window.supabase.createClient(DS_SUPABASE_URL, DS_SUPABASE_KEY);
}
