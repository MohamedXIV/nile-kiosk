// Observe Godot's real asynchronous IDBFS flush. No browser save is seeded or
// modified: acceptance reloads only after the requested on-disk revision exists.
export async function waitForGodotSave(page, filename, matches) {
  let observed=null;
  for(let attempt=0;attempt<100;attempt++) {
    observed=await page.evaluate(async filename=>{
      for(const info of await indexedDB.databases()) {
        const db=await new Promise((resolve,reject)=>{const q=indexedDB.open(info.name);q.onsuccess=()=>resolve(q.result);q.onerror=()=>reject(q.error);});
        try {
          if(!db.objectStoreNames.contains('FILE_DATA'))continue;
          const entries=await new Promise((resolve,reject)=>{
            const values=[];const q=db.transaction('FILE_DATA','readonly').objectStore('FILE_DATA').openCursor();
            q.onsuccess=()=>{const c=q.result;if(!c){resolve(values);return;}values.push({key:c.key,value:c.value});c.continue();};q.onerror=()=>reject(q.error);
          });
          for(const e of entries)if(String(e.key).endsWith('/'+filename)) {
            try{return JSON.parse(new TextDecoder().decode(e.value.contents));}catch{}
          }
        } finally {db.close();}
      }
      return null;
    },filename);
    if(observed && matches(observed))return observed;
    await page.waitForTimeout(150);
  }
  throw new Error('Godot save did not reach requested persisted revision: '+filename+' observed='+observed?.sequence);
}
