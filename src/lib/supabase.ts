import { createClient } from '@supabase/supabase-js';
const url=import.meta.env.VITE_SUPABASE_URL,key=import.meta.env.VITE_SUPABASE_PUBLISHABLE_KEY;
export const configured=Boolean(url&&key&&!url.includes('TU-PROYECTO')&&!key.includes('REEMPLAZAR'));
export const supabase=createClient(configured?url:'https://example.supabase.co',configured?key:'not-configured',{auth:{persistSession:true,autoRefreshToken:true,detectSessionInUrl:true}});
export function check<T>(r:{data:T;error:{message:string}|null}):T {if(r.error)throw new Error(r.error.message);return r.data;}
