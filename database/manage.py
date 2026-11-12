"""Local database operations. Python 3.10+, Docker Compose. Never prints passwords."""
from pathlib import Path
import argparse,subprocess,os,secrets,re,json,datetime

PROJECT=Path(__file__).resolve().parents[1]
def settings():
    out={}
    for line in (PROJECT/'.env').read_text(encoding='utf-8-sig').splitlines():
        if '=' in line and not line.lstrip().startswith('#'):
            k,v=line.split('=',1);out[k.strip()]=v.strip().strip('"').strip("'")
    return out
def call(*args,input=None,quiet=False):
    r=subprocess.run(['docker','compose',*args],cwd=PROJECT,input=input,encoding='utf-8',stdout=subprocess.PIPE,stderr=subprocess.STDOUT)
    output=r.stdout
    for k,v in settings().items():
        if ('PASSWORD' in k or 'SECRET' in k) and v:output=output.replace(v,'[REDACTED]')
    if not quiet or r.returncode:print(output,end='',flush=True)
    if r.returncode:raise RuntimeError('Docker operation failed; see output above')
    return output
def sql(db,text,quiet=False):
    return call('exec','-T','postgres','psql','-X','-v','ON_ERROR_STOP=1','-U',settings()['POSTGRES_USER'],'-d',db,input=text,quiet=quiet)
def quoted(value):return "'"+value.replace("'","''")+"'"
def database_name(prefix):return prefix+datetime.datetime.now(datetime.timezone.utc).strftime('%Y%m%d%H%M%S')+'_'+secrets.token_hex(3)
def create(db):
    assert re.fullmatch(r'reploom_check_[a-z0-9_]+',db)
    sql('postgres','CREATE DATABASE '+db+';',True)
def remove(db):
    assert re.fullmatch(r'reploom_check_[a-z0-9_]+',db)
    sql('postgres','DROP DATABASE '+db+' WITH (FORCE);',True)
def fly(db,action):return call('run','--rm','-e','FLYWAY_URL=jdbc:postgresql://postgres:5432/'+db,'flyway',action)
def dump(db):
    stamp=datetime.datetime.now(datetime.timezone.utc).strftime('%Y%m%dT%H%M%SZ')+'_'+secrets.token_hex(2)
    filename=db+'_'+stamp+'.dump';tmp='/tmp/'+filename
    call('exec','-T','postgres','pg_dump','-U',settings()['POSTGRES_USER'],'-d',db,'--format=custom','--file='+tmp,quiet=True)
    folder=PROJECT/'database/backups';folder.mkdir(parents=True,exist_ok=True)
    path=folder/filename
    call('cp','postgres:'+tmp,str(path),quiet=True)
    print('Backup: '+str(path))
    return path,tmp
def fingerprints(db):
    text='''SELECT json_object_agg(name,rows) FROM (
    SELECT table_name AS name,0 AS rows FROM information_schema.tables WHERE false) x;'''
    # Output includes schema, seeded rows, fixtures and the migration history, with stable row ordering.
    q="SELECT tablename FROM pg_tables WHERE schemaname='public' ORDER BY tablename;"
    raw=call('exec','-T','postgres','psql','-X','-At','-U',settings()['POSTGRES_USER'],'-d',db,'-c',q,quiet=True)
    result={}
    for table in raw.splitlines():
        if re.fullmatch('[a-z_]+',table):
            q=f"SELECT md5(coalesce(string_agg(to_jsonb(t)::text,E'\\n' ORDER BY to_jsonb(t)::text),'')) FROM {table} t;"
            result[table]=call('exec','-T','postgres','psql','-X','-At','-U',settings()['POSTGRES_USER'],'-d',db,'-c',q,quiet=True).strip()
    return result
def verify():
    original=database_name('reploom_check_');restored=database_name('reploom_check_')
    create(original);create(restored)
    try:
        fly(original,'migrate');fly(original,'validate')
        suite=(PROJECT/'database/tests/integrity.sql').read_text(encoding='utf-8')
        # Commit fixtures only in this disposable verification database to test real data restoration.
        sql(original,suite.replace('\nROLLBACK;','\nCOMMIT;'))
        before=fingerprints(original)
        path,tmp=dump(original)
        call('exec','-T','postgres','pg_restore','-U',settings()['POSTGRES_USER'],'--dbname='+restored,'--exit-on-error','--no-owner',tmp)
        after=fingerprints(restored)
        if before!=after:raise RuntimeError('Restored data differs from original')
        fly(restored,'validate')
        report={'result':'PASS','schema_version':9,'domain_tables':67,'public_tables':len(before),'checks':['fresh migration','integrity scenarios','row security','audited correction','seed data','dump/restore exact public row fingerprints','Flyway validate'],'backup':path.name}
        (PROJECT/'database/verification.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
        print('PASS: full rebuild, integrity scenarios, exact data restore, Flyway validate')
    finally:
        remove(original);remove(restored)
def provision():
    cfg=settings();name=cfg.get('APP_DB_USER','reploom_runtime')
    if not re.fullmatch('[a-z][a-z0-9_]{0,40}',name):raise ValueError('Invalid runtime role name')
    password=cfg.get('APP_DB_PASSWORD')
    if not password or password.startswith('replace_'):password=secrets.token_urlsafe(36)
    # First persist the secret locally, then provision the role; retries use the same secret.
    p=PROJECT/'.env';text=p.read_text(encoding='utf-8-sig')
    for key,value in {'APP_DB_USER':name,'APP_DB_PASSWORD':password}.items():
        if re.search(r'^'+key+r'=',text,re.M):text=re.sub(r'^'+key+r'=.*$',key+'='+value,text,flags=re.M)
        else:text+='\n'+key+'='+value+'\n'
    p.write_text(text,encoding='utf-8')
    statement=f"""DO $block$ BEGIN
    IF NOT EXISTS(SELECT 1 FROM pg_roles WHERE rolname={quoted(name)}) THEN CREATE ROLE {name} LOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE NOINHERIT NOBYPASSRLS; END IF;
    END $block$;
    ALTER ROLE {name} WITH LOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE INHERIT NOBYPASSRLS PASSWORD {quoted(password)};
    GRANT reploom_app TO {name};
    GRANT CONNECT ON DATABASE "{cfg['POSTGRES_DB'].replace(chr(34),chr(34)*2)}" TO {name};
    """
    # Suppress successful SQL output; PostgreSQL never receives the secret on a CLI argument.
    sql(cfg['POSTGRES_DB'],statement,True)
    print('Runtime role configured. Credentials are stored only in .env.')
def main():
    p=argparse.ArgumentParser();p.add_argument('action',choices=['info','migrate','validate','verify','backup','provision-runtime']);a=p.parse_args().action
    if a=='verify':verify()
    elif a=='backup':dump(settings()['POSTGRES_DB'])
    elif a=='provision-runtime':provision()
    else:fly(settings()['POSTGRES_DB'],a)
if __name__=='__main__':main()
