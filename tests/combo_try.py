import sys,os,tempfile
sys.path.insert(0,os.path.dirname(__file__))
import sim_flow, run_matrix
from xlsx_builder import write_workbook
names=sys.argv[1:] or ['shipped']
d=tempfile.mkdtemp(prefix='pp_')
for name in names:
    aw,sl=run_matrix.SCENARIOS[name]
    for rin in (0,1):
        for rout in (0,1):
            x=write_workbook(os.path.join(d,f'x{rin}{rout}.xlsx'),module='m_t',aw=aw,dw=32,rebase=1,slaves=sl,formulas=False,
                             extra_master=[('Register Inputs',rin,'x'),('Register Outputs',rout,'x')])
            r=sim_flow.simulate(x,os.path.join(d,f'{name}w{rin}{rout}'))
            print(name,rin,rout,r['status'],r['checks'],r['failed'])
            if r['status']!='PASS': print(r['log'][-1200:])
