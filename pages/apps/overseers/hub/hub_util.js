export async function fetchJSON(url){
  const res = await fetch(url, { cache: 'no-store' });
  if(!res.ok) throw new Error('HTTP ' + res.status);
  return res.json();
}
