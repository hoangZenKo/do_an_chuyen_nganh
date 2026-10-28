import json, sys, re, textwrap, html
from pathlib import Path

OUT=Path('/tmp/rental-report-20261028')
ROOT=Path('/Users/hoang/Rental_room_management')
sys.path.insert(0,str(OUT))
from report_data import MODEL_GROUPS, GROUPS, SEQUENCES
data=json.loads((OUT/'audit.json').read_text())
diagrams=[]
directory=OUT/'diagrams';directory.mkdir(exist_ok=True)

def dotq(text): return json.dumps(str(text),ensure_ascii=False)
def wrap(text,width=25): return '\n'.join(textwrap.wrap(text,width=width,break_long_words=False))
def dot_base():
    return ['digraph G {','graph [bgcolor="white", rankdir=LR, nodesep=0.30, ranksep=0.65, pad=0.2, splines=polyline];','node [fontname="Times New Roman", fontsize=17, color="black", fontcolor="black", style="filled", fillcolor="white", penwidth=1.1];','edge [fontname="Times New Roman", fontsize=14, color="black", arrowsize=0.7, penwidth=0.9];']
def register(key,title,lines,kind,description,source=None):
    (directory/(key+'.dot')).write_text('\n'.join(lines+['}']))
    diagrams.append(dict(id=key,title=title,kind=kind,description=description,source=source or 'backend/prisma/schema.prisma'))

lines=dot_base();lines[1]='graph [bgcolor="white",rankdir=TB,nodesep=0.45,ranksep=0.50,pad=0.2];'
for name,label in [('users','Admin / Chủ trọ / Staff\nNgười tìm phòng / Người thuê'),('ui','Flutter\nGoRouter · Riverpod · Dio'),('api','NestJS REST API /api/v1\nJWT · Roles · Permissions · Property Scope'),('domain','Các service nghiệp vụ\nBilling · Leases · Listings · Support · Admin'),('db','Prisma ORM → PostgreSQL'),('worker','Scheduler / Outbox / Delivery\nTùy cấu hình môi trường'),('external','Uploads · Email/Zalo provider\nOllama/nguồn tri thức (tùy cấu hình)')]:
    lines.append(f'{name} [shape=box,label={dotq(label)}];')
for a,b,label in [('users','ui','Thao tác'),('ui','api','HTTPS + token'),('api','domain','Kiểm tra quyền/đầu vào'),('domain','db','Transaction và truy vấn'),('worker','db','Lấy job, ghi kết quả'),('domain','worker','Ghi sự kiện/job'),('worker','external','Gửi theo cấu hình')]: lines.append(f'{a} -> {b} [label={dotq(label)}];')
register('AR-01','Kiến trúc tổng thể và ranh giới tích hợp',lines,'architecture','Backend là modular monolith; worker và dịch vụ ngoài không được suy ra là đã nghiệm thu production.','backend/src/app.module.ts')

lines=dot_base();lines[1]='graph [bgcolor="white",rankdir=TB,nodesep=0.4,ranksep=0.55,pad=0.2];'
for name,label in [('a','Yêu cầu từ Flutter'),('b','Xác thực JWT và phiên'),('c','Roles / Permissions / Capability'),('d','PropertyScopeInterceptor cho Staff'),('e','Ownership và quy tắc tại Service'),('f','Transaction Prisma / dữ liệu'),('g','Lỗi chuẩn hóa hoặc kết quả có projection')]:lines.append(f'{name} [shape=box,label={dotq(label)}];')
lines += ['a -> b -> c -> d -> e -> f -> g;','c -> g [label="Từ chối quyền",style=dashed];','e -> g [label="Ngoài scope / xung đột",style=dashed];']
register('AR-02','Các lớp kiểm tra truy cập',lines,'architecture','Có permission chưa đủ: còn scope, ownership và quy tắc trạng thái. Staff bị chặn controller chưa hỗ trợ property scope.','backend/src/common/property-scope.ts')

for group,meta in GROUPS.items():
    cases=[c for c in data['cases'] if c['group']==group]
    for index in range(0,len(cases),7):
        chunk=cases[index:index+7]; key=f'D-{group}-{index//7+1:02}'
        lines=dot_base()
        actors=sorted({actor for case in chunk for actor in case['diagram_actors']})
        actor_ids={actor:f'actor{i}' for i,actor in enumerate(actors)}
        for actor,actor_id in actor_ids.items():
            lines.append(f'{actor_id} [shape=box,label={dotq("«actor»\n"+wrap(actor,22))}];')
        lines.append(f'subgraph cluster_system {{ label={dotq("Rental Room Management · "+meta[0])};fontname="Times New Roman";fontsize=18;color="black";')
        for i,c in enumerate(chunk):lines.append(f'u{i} [shape=ellipse,label={dotq(c["id"]+"\n"+wrap(c["title"],29))},margin="0.12,0.08"];')
        lines.append('}')
        for i,c in enumerate(chunk):
            for actor in c['diagram_actors']:lines.append(f'{actor_ids[actor]} -> u{i} [arrowhead=none];')
        register(key,meta[0]+f' — phần {index//7+1}',lines,'usecase','Các đường nối thể hiện liên kết tác nhân–UC, không suy diễn include/extend cho thao tác dùng chung. Quyền chi tiết xem bảng UC.','backend/src/'+meta[1].split(',')[0])

for key,title,names in MODEL_GROUPS:
    names=[n for n in names if n in data['models']]
    lines=dot_base(); lines[1]='graph [bgcolor="white",rankdir=LR,nodesep=0.35,ranksep=0.85,pad=0.15,splines=polyline];'
    for name in names:
        fields=[f for f in data['models'][name]['fields'] if f['type'].rstrip('?[]') not in data['models']]
        priorities=['id','landlordId','userId','tenantId','roomId','leaseId','invoiceId','receiptId','status','amount','totalAmount','paidAmount','availableAmount','version','billingMonth','startDate','endDate']
        fields=sorted(fields,key=lambda f:priorities.index(f['name']) if f['name'] in priorities else 100)[:5]
        attributes=''.join(f'<TR><TD ALIGN="LEFT">{html.escape(f["name"]+": "+f["type"])}</TD></TR>' for f in fields)
        label=f'<<TABLE BORDER="1" CELLBORDER="0" CELLSPACING="0" CELLPADDING="5"><TR><TD><B>{name}</B></TD></TR><TR><TD BORDER="1" SIDES="T"></TD></TR>{attributes}</TABLE>>'
        lines.append(f'{name} [shape=plain,label={label}];')
    for rel in data['relations']:
        if rel['source'] not in names or rel['target'] not in names:continue
        if rel['source']==rel['target']:continue
        model=data['models'][rel['source']]
        fk=rel['fk']; is_unique=any(f['name']==fk and ('@unique' in f['attrs'] or '@id' in f['attrs']) for f in model['fields'])
        target_multiplicity='0..1' if rel['optional'] else '1'
        source_multiplicity='0..1' if is_unique else '0..*'
        lines.append(f'{rel["source"]} -> {rel["target"]} [dir=none,label={dotq(rel["field"])},taillabel={dotq(source_multiplicity)},headlabel={dotq(target_multiplicity)},labeldistance=2.1];')
    register(key,title,lines,'class','Các lớp biểu diễn thực thể nghiệp vụ và các thuộc tính tiêu biểu; không tự gắn phương thức CRUD vào entity. Hình dùng để giải thích UC, không thay thế schema database.')

def sequence_svg(spec):
    key,title,refs,source,actors,messages,note=spec
    width=1320; top=130; row_height=76; bottom=top+row_height*len(messages)
    note_lines=textwrap.wrap(note,91,break_long_words=False)
    height=bottom+55+len(note_lines)*30+35
    xs=[135,470,805,1185]
    parts=[f'<svg xmlns="http://www.w3.org/2000/svg" width="{width}" height="{height}" viewBox="0 0 {width} {height}">', '<rect width="100%" height="100%" fill="white"/>','<defs><marker id="arrow" markerWidth="9" markerHeight="9" refX="8" refY="4" orient="auto"><path d="M0,0 L8,4 L0,8" fill="none" stroke="black" stroke-width="1.5"/></marker></defs>']
    for x,label in zip(xs,actors):
        parts.append(f'<rect x="{x-122}" y="15" width="244" height="72" fill="white" stroke="black" stroke-width="2"/>')
        for idx,line in enumerate(textwrap.wrap(label,22)):
            parts.append(f'<text x="{x}" y="{44+idx*27}" text-anchor="middle" font-family="Times New Roman" font-size="25">{html.escape(line)}</text>')
        parts.append(f'<line x1="{x}" y1="87" x2="{x}" y2="{bottom+5}" stroke="black" stroke-dasharray="9 7"/>')
    for idx,(sender,receiver,label) in enumerate(messages):
        y=top+idx*row_height; x1,x2=xs[sender],xs[receiver]
        if sender==receiver:
            parts.append(f'<path d="M{x1},{y} h65 v25 h-65" fill="none" stroke="black" stroke-width="2" marker-end="url(#arrow)"/>')
            tx=min(x1+100,width-250); anchor='middle'; label_width=34
        else:
            parts.append(f'<line x1="{x1}" y1="{y+23}" x2="{x2}" y2="{y+23}" stroke="black" stroke-width="2" marker-end="url(#arrow)"/>')
            tx=(x1+x2)/2;anchor='middle';label_width=40 if abs(x1-x2)>400 else 29
        wrapped=textwrap.wrap(f'{idx+1}. {label}',label_width,break_long_words=False)
        for li,line in enumerate(wrapped[:2]):
            parts.append(f'<text x="{tx}" y="{y-15+li*27}" text-anchor="{anchor}" font-family="Times New Roman" font-size="24">{html.escape(line)}</text>')
    parts.append(f'<rect x="15" y="{bottom+22}" width="1290" height="{len(note_lines)*30+42}" fill="white" stroke="black" stroke-width="1.5"/>')
    for i,line in enumerate(note_lines):
        parts.append(f'<text x="35" y="{bottom+53+i*30}" font-family="Times New Roman" font-size="24">{html.escape(line)}</text>')
    parts.append('</svg>')
    (directory/(key+'.svg')).write_text(''.join(parts))
    diagrams.append(dict(id=key,title=title,kind='sequence',description=note,source='backend/src/'+source,refs=refs))
for sequence in SEQUENCES:sequence_svg(sequence)

lines=dot_base();lines[1]='graph [bgcolor="white",rankdir=TB,nodesep=0.4,ranksep=0.5,pad=0.2];'
for key,label in [('r','receipt01: BillingReceipt\namount=3.000.000; available=500.000'),('a','alloc01: PaymentAllocation\namount=2.500.000; releasedAt=null'),('p','payment01: Payment\namount=2.500.000; type=PAYMENT'),('i','invoice01: Invoice\ntotalAmount=4.000.000\npaidAmount=2.500.000; status=PARTIAL'),('t','tenant01: Tenant\nHồ sơ giả định, không phải dữ liệu thật')]:lines.append(f'{key} [shape=box,label={dotq(label)}];')
for edge in ['r -> a [label="allocations"];','a -> p [label="payment"];','a -> i [label="invoice"];','r -> t [label="tenant"];','i -> t [label="tenant"];']:lines.append(edge)
register('OD-01','Đối tượng khoản thu và hóa đơn thanh toán một phần',lines,'object','Ví dụ giả định: 3.000.000 đồng nhận, 2.500.000 phân bổ, 500.000 còn khả dụng; công nợ hóa đơn còn 1.500.000 đồng.')

(OUT/'diagram-manifest.json').write_text(json.dumps(diagrams,ensure_ascii=False,indent=2))
print('Diagram sources:',len(diagrams),dict(__import__('collections').Counter(d['kind'] for d in diagrams)))
