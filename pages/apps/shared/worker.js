export function getWorker(){return localStorage.getItem('worker_url')||''}
export function setWorker(u){localStorage.setItem('worker_url',u)}