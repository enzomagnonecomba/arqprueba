import {useState} from 'react';
import type {FormEvent} from 'react';
import {Building2} from 'lucide-react';
import {check,supabase} from '../lib/supabase';
export default function Auth({recovery,onRecovered}:{recovery:boolean;onRecovered:()=>void}){
 const [mode,setMode]=useState<'login'|'register'|'recover'>('login'),[busy,setBusy]=useState(false),[message,setMessage]=useState('');
 async function submit(e:FormEvent<HTMLFormElement>){e.preventDefault();setBusy(true);setMessage('');const f=new FormData(e.currentTarget),email=String(f.get('email')||'').trim(),password=String(f.get('password')||'');try{
 if(recovery){check(await supabase.auth.updateUser({password}));onRecovered();}
 else if(mode==='login')check(await supabase.auth.signInWithPassword({email,password}));
 else if(mode==='register'){check(await supabase.auth.signUp({email,password,options:{data:{full_name:String(f.get('name')||'').trim()},emailRedirectTo:location.origin+'/'}}));setMessage('Cuenta creada. Revisá tu correo para confirmarla antes de ingresar.');}
 else {check(await supabase.auth.resetPasswordForEmail(email,{redirectTo:location.origin+'/?recovery=1'}));setMessage('Si el correo está registrado, recibirás un enlace de recuperación.');}
 }catch(e){setMessage((e as Error).message);}finally{setBusy(false);}}
 return <div className="auth"><aside><Building2 size={36}/><h1>Tu obra,<br/>más organizada.</h1><p>Tareas, materiales y equipo en un mismo lugar.</p></aside><main><form onSubmit={submit}><h1>{recovery?'Nueva contraseña':mode==='login'?'Ingresar a Obra':mode==='register'?'Crear cuenta':'Recuperar acceso'}</h1><p className="muted">Cada persona ingresa con su cuenta.</p>{!recovery&&<>{mode==='register'&&<label>Nombre y apellido<input name="name" required maxLength={120} autoComplete="name"/></label>}<label>Correo<input name="email" type="email" required autoComplete="email"/></label></>}{(recovery||mode!=='recover')&&<label>Contraseña<input name="password" type="password" minLength={8} required autoComplete={mode==='login'&&!recovery?'current-password':'new-password'}/></label>}<button className="primary" disabled={busy}>{busy?'Procesando…':recovery?'Guardar contraseña':mode==='login'?'Ingresar':mode==='register'?'Registrarme':'Enviar enlace'}</button>{message&&<p className="notice" role="status">{message}</p>}{!recovery&&<div className="auth-links"><button type="button" onClick={()=>{setMode(mode==='register'?'login':'register');setMessage('');}}>{mode==='register'?'Ya tengo cuenta':'Crear cuenta'}</button><button type="button" onClick={()=>{setMode(mode==='recover'?'login':'recover');setMessage('');}}>{mode==='recover'?'Volver al login':'Olvidé mi contraseña'}</button></div>}{recovery&&<button type="button" onClick={onRecovered}>Volver</button>}</form></main></div>;
}
