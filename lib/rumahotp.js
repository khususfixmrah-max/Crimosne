const BASE="https://www.rumahotp.io";
function headers(){if(!process.env.RUMAHOTP_API_KEY)throw new Error("RUMAHOTP_API_KEY is missing");return{"x-apikey":process.env.RUMAHOTP_API_KEY,"Accept":"application/json"}}
async function request(path){const r=await fetch(BASE+path,{headers:headers(),cache:"no-store"});const j=await r.json().catch(()=>({}));if(!r.ok||j.success===false)throw new Error(j?.error?.message||`RumahOTP HTTP ${r.status}`);return j}
export const createDeposit=amount=>request(`/api/v1/deposit/create?amount=${encodeURIComponent(amount)}&payment_id=qris`);
export const getDepositStatus=id=>request(`/api/v2/deposit/get_status?deposit_id=${encodeURIComponent(id)}`);
export const getServices=()=>request("/api/v2/services");
