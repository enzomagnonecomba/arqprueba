export const taskStates=['Por comenzar','En curso','En pausa','Terminada'] as const;
export type TaskState=typeof taskStates[number];
export const trades=['Albañilería','Estructura','Instalación eléctrica','Instalación sanitaria','Terminaciones','Pintura','Carpintería'];
export type Role='Administrador'|'Jefe de Obra';
export interface Studio {id:string;name:string;}
export interface Membership {studio_id:string;user_id:string;role:Role;studios:Studio;}
export interface Project {id:string;studio_id:string;name:string;address:string;budget:number;status:string;}
export interface Member {user_id:string;role:Role;full_name:string;email:string;}
export interface Task {id:string;project_id:string;title:string;trade:string;assignee_id:string|null;priority:'Baja'|'Media'|'Alta';due_date:string|null;status:TaskState;tags:string[];description:string;created_at:string;}
export interface Item {id?:string;description:string;unit:string;quantity:number;received:number;note:string;}
export interface Order {id:string;project_id:string;number:number;supplier:string;trade:string;due_date:string;status:string;notes:string;created_at:string;order_items:Item[];}
export interface Attachment {id:string;project_id:string;order_id:string|null;name:string;path:string;}
