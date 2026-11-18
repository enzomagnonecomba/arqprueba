import {check,supabase} from './supabase';
import type {Item,Order,Task,Attachment,Member} from '../types';
export const api={
 async tasks(p:string){return check(await supabase.from('tasks').select('*').eq('project_id',p).order('created_at',{ascending:false})) as Task[];},
 async saveTask(v:Partial<Task>,id?:string){check(id?await supabase.from('tasks').update(v).eq('id',id).select().single():await supabase.from('tasks').insert(v).select().single());},
 async deleteTask(id:string){check(await supabase.from('tasks').delete().eq('id',id));},
 async members(p:string){return check(await supabase.rpc('list_project_members',{p_project:p})) as Member[];},
 async orders(p:string){return check(await supabase.from('orders').select('*,order_items(*)').eq('project_id',p).order('created_at',{ascending:false})) as Order[];},
 async createOrder(p:string,v:{supplier:string;trade:string;due_date:string;notes:string},items:Item[],draft:boolean){return check(await supabase.rpc('create_order',{p_project:p,p_supplier:v.supplier,p_trade:v.trade,p_due:v.due_date,p_notes:v.notes,p_items:items,p_draft:draft})) as string;},
 async status(id:string,status:string){check(await supabase.rpc('change_order_status',{p_order:id,p_status:status}));},
 async receive(id:string,items:{id:string;quantity:number}[]){check(await supabase.rpc('receive_order',{p_order:id,p_items:items}));},
 async attachments(id:string){return check(await supabase.from('attachments').select('*').eq('order_id',id)) as Attachment[];},
 async upload(p:string,o:string,file:File){
  if(file.size>10485760)throw new Error('El archivo supera 10 MB.');
  const ext=file.name.split('.').pop()?.toLowerCase();if(!['jpg','jpeg','png','webp','pdf'].includes(ext||''))throw new Error('Solo JPG, PNG, WEBP o PDF.');
  const path=`${p}/${crypto.randomUUID()}.${ext}`;
  check(await supabase.storage.from('obra-files').upload(path,file));
  const r=await supabase.from('attachments').insert({project_id:p,order_id:o,name:file.name,path,size:file.size,mime_type:file.type});
  if(r.error){await supabase.storage.from('obra-files').remove([path]);throw new Error(r.error.message);}
 },
 async download(path:string){return check(await supabase.storage.from('obra-files').createSignedUrl(path,60)).signedUrl;}
};
