const supabaseUrl = 'https://xywcjkxqgrrbwfcknetc.supabase.co';
// 注意：web 端 realtime 对新版 sb_publishable_ key 不建立 WebSocket（实测），
// 统一用 legacy anon JWT key，三端 realtime 均正常。
const supabasePublishableKey =
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inh5d2Nqa3hxZ3JyYndmY2tuZXRjIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODA3NzIwMzcsImV4cCI6MjA5NjM0ODAzN30.l6IJq_T0p2KB_EUlIZhF_l_e6MA8LpvXUSVAPS_Fcxk';
