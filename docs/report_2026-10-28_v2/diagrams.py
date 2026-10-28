import json, sys, re, textwrap, html
from pathlib import Path

OUT=Path('/tmp/rental-report-v2-20261028')
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
for name,label in [('users','Admin / Chủ trọ / Người thuê\nKhách vãng lai'),('ui','Flutter\nGoRouter · Riverpod · Dio'),('api','NestJS REST API /api/v1\nJWT · Roles · Permissions · Property Scope'),('domain','Các service nghiệp vụ\nBilling · Leases · Listings · Support · Admin'),('db','Prisma ORM → PostgreSQL'),('worker','Scheduler / Outbox / Delivery\nTùy cấu hình môi trường'),('external','Uploads · Email/Zalo provider\nOllama/nguồn tri thức (tùy cấu hình)')]:
    lines.append(f'{name} [shape=box,label={dotq(label)}];')
for a,b,label in [('users','ui','Thao tác'),('ui','api','HTTPS + token'),('api','domain','Kiểm tra quyền/đầu vào'),('domain','db','Transaction và truy vấn'),('worker','db','Lấy job, ghi kết quả'),('domain','worker','Ghi sự kiện/job'),('worker','external','Gửi theo cấu hình')]: lines.append(f'{a} -> {b} [label={dotq(label)}];')
register('AR-01','Kiến trúc tổng thể và ranh giới tích hợp',lines,'architecture','Backend là modular monolith; worker và dịch vụ ngoài không được suy ra là đã nghiệm thu production.','backend/src/app.module.ts')

lines=dot_base();lines[1]='graph [bgcolor="white",rankdir=TB,nodesep=0.4,ranksep=0.55,pad=0.2];'
for name,label in [('a','Yêu cầu từ Flutter'),('b','Xác thực JWT và phiên'),('c','Roles / Permissions / Capability'),('d','Phạm vi tài nguyên theo vai trò'),('e','Ownership và quy tắc tại Service'),('f','Transaction Prisma / dữ liệu'),('g','Lỗi chuẩn hóa hoặc kết quả có projection')]:lines.append(f'{name} [shape=box,label={dotq(label)}];')
lines += ['a -> b -> c -> d -> e -> f -> g;','c -> g [label="Từ chối quyền",style=dashed];','e -> g [label="Ngoài scope / xung đột",style=dashed];']
register('AR-02','Các lớp kiểm tra truy cập',lines,'architecture','Có permission chưa đủ: còn scope, ownership và quy tắc trạng thái. Người thuê chỉ truy cập hồ sơ liên kết của mình.','backend/src/common/property-scope.ts')

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

# Replace the compact Graphviz actor boxes with standard stick-figure actors.
# The old generated entries remain as source history, but only this manifest is used.
diagrams=[d for d in diagrams if d['kind']!='usecase']
ACTOR_ORDER=['Khách vãng lai','Người thuê','Chủ trọ','Admin']
ACTOR_GROUPS={
    'Khách vãng lai':{'SYS','DIS'},
    'Người thuê':{'SYS','DIS','TNT','TEN'},
    'Chủ trọ':{'SYS','DIS','OPT','TNT','BIL','OPS','ADM','SUP'},
    'Admin':{'SYS','ADM','SUP'},
}
GROUP_COLORS={'SYS':'#E53935','DIS':'#F39C12','OPT':'#F39C12','TNT':'#F39C12','BIL':'#3D7EFF','OPS':'#3D7EFF','TEN':'#22A95A','ADM':'#7C8DA6','SUP':'#7C8DA6'}
def person_svg(x,y,label,scale=1.0):
    s=scale
    return [f'<circle cx="{x}" cy="{y}" r="{18*s}" fill="white" stroke="#20242b" stroke-width="3"/>',
            f'<line x1="{x}" y1="{y+18*s}" x2="{x}" y2="{y+73*s}" stroke="#20242b" stroke-width="3"/>',
            f'<line x1="{x-34*s}" y1="{y+38*s}" x2="{x+34*s}" y2="{y+38*s}" stroke="#20242b" stroke-width="3"/>',
            f'<line x1="{x}" y1="{y+73*s}" x2="{x-30*s}" y2="{y+115*s}" stroke="#20242b" stroke-width="3"/>',
            f'<line x1="{x}" y1="{y+73*s}" x2="{x+30*s}" y2="{y+115*s}" stroke="#20242b" stroke-width="3"/>',
            f'<text x="{x}" y="{y+150*s}" text-anchor="middle" font-family="Times New Roman" font-size="22">{html.escape(label)}</text>']
def usecase_svg(key,title,cases,source):
    width=1200; top=160; row=110; height=max(1020,top+row*len(cases)+40)
    parts=[f'<svg xmlns="http://www.w3.org/2000/svg" width="{width}" height="{height}" viewBox="0 0 {width} {height}"><rect width="100%" height="100%" fill="white"/>',
           f'<text x="600" y="36" text-anchor="middle" font-family="Times New Roman" font-size="26" font-weight="bold">{html.escape(title)}</text>',
           f'<rect x="180" y="70" width="840" height="{height-100}" fill="white" stroke="#20242b" stroke-width="2"/>',
           '<text x="600" y="106" text-anchor="middle" font-family="Times New Roman" font-size="24" font-weight="bold">Hệ thống quản lý nhà trọ</text>']
    active=set(a for case in cases for a in case['diagram_actors'])
    positions={'Khách vãng lai':(82,205),'Người thuê':(82,height-320),'Chủ trọ':(1118,205),'Admin':(1118,height-320)}
    for label in ACTOR_ORDER:
        if label not in active:continue
        x,y=positions[label]
        for j,case in enumerate(cases):
            if label not in case['diagram_actors']:continue
            endx=280 if x<600 else 920
            parts.append(f'<line x1="{x}" y1="{y+38}" x2="{endx}" y2="{top+j*row}" stroke="#acb5c4" stroke-width="1.3"/>')
    for j,case in enumerate(cases):
        cy=top+j*row; color=GROUP_COLORS.get(case['group'],'#3D7EFF')
        parts.append(f'<ellipse cx="600" cy="{cy}" rx="320" ry="44" fill="white" stroke="{color}" stroke-width="2"/>')
        labels=[case['id']]+textwrap.wrap(case['title'],42,break_long_words=False)
        for li,line in enumerate(labels):
            yy=cy-(len(labels)-1)*12+li*25
            parts.append(f'<text x="600" y="{yy+7}" text-anchor="middle" font-family="Times New Roman" font-size="23" font-weight="{"bold" if li==0 else "normal"}">{html.escape(line)}</text>')
    for label in ACTOR_ORDER:
        if label in active:parts += person_svg(*positions[label],label,0.85)
    parts.append('</svg>')
    (directory/(key+'.svg')).write_text(''.join(parts))
    diagrams.append(dict(id=key,title=title,kind='usecase',description='Tác nhân hình người nằm ngoài biên hệ thống; đường association nối trực tiếp tới ellipse UC. Mã nhóm ở sơ đồ tổng được phân rã trong các hình và đặc tả tiếp theo.',source=source))

# One overview diagram following the old centralized form, updated to current UC groups.
overview_cases=[]
for group,meta in GROUPS.items():
    overview_cases.append({'id':'UC-'+group,'title':meta[0],'group':group,'diagram_actors':[a for a in ACTOR_ORDER if group in ACTOR_GROUPS[a]]})
usecase_svg('UC-OVERVIEW','Sơ đồ Use Case tổng quan — Hệ thống quản lý nhà trọ',overview_cases,'docs/ba/use-case-centralized.drawio')
for group,meta in GROUPS.items():
    cases=[c for c in data['cases'] if c['group']==group]
    for index in range(0,len(cases),7):
        chunk=cases[index:index+7];key=f'D-{group}-{index//7+1:02}'
        usecase_svg(key,meta[0]+f' — phần {index//7+1}',chunk,'backend/src/'+meta[1].split(',')[0])

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
    for offset in range(0,len(messages),7):
        panel=messages[offset:offset+7]; part=offset//7+1; parts_count=(len(messages)+6)//7
        panel_key=key+('-'+str(part) if parts_count>1 else '')
        width=1200;top=245;row=100;bottom=top+row*len(panel)+25;height=bottom+75
        xs=[100,410,735,1090];yellow='#FFFFB9';red='#800000'
        parts=[f'<svg xmlns="http://www.w3.org/2000/svg" width="{width}" height="{height}" viewBox="0 0 {width} {height}"><rect width="100%" height="100%" fill="white"/>',
          '<defs><marker id="call" markerWidth="8" markerHeight="8" refX="7" refY="4" orient="auto"><path d="M0,0 L7,4 L0,8 Z" fill="#800000"/></marker><marker id="return" markerWidth="9" markerHeight="9" refX="8" refY="4" orient="auto"><path d="M0,0 L8,4 L0,8" fill="none" stroke="#800000" stroke-width="1.5"/></marker></defs>']
        for idx,(x,label) in enumerate(zip(xs,actors)):
            if idx==0:
                parts+=person_svg(x,44,'',0.56)
                parts.append(f'<circle cx="{x}" cy="44" r="10" fill="{yellow}" stroke="{red}"/>')
            elif idx==1:
                parts += [f'<circle cx="{x}" cy="73" r="29" fill="{yellow}" stroke="{red}" stroke-width="1.6"/>',f'<path d="M{x-42},48 v50 M{x-42},73 h13" stroke="{red}" fill="none" stroke-width="1.6"/>']
            elif idx==2:
                parts += [f'<circle cx="{x}" cy="73" r="29" fill="{yellow}" stroke="{red}" stroke-width="1.6"/>',f'<path d="M{x+8},39 l-16,5 l13,10" stroke="{red}" fill="none" stroke-width="1.6"/>']
            else:
                parts += [f'<path d="M{x-31},53 v45 a31,10 0 0 0 62,0 V53" fill="{yellow}" stroke="{red}" stroke-width="1.6"/>',f'<ellipse cx="{x}" cy="53" rx="31" ry="10" fill="{yellow}" stroke="{red}" stroke-width="1.6"/>']
            label=label.replace('Flutter Admin','Giao diện Admin').replace('Flutter','Giao diện').replace('Prisma/DB','CSDL PostgreSQL')
            for li,line in enumerate(textwrap.wrap(label,19,break_long_words=False)):
                parts.append(f'<text x="{x}" y="{151+li*27}" text-anchor="middle" font-family="Times New Roman" font-size="25" text-decoration="{"underline" if idx else "none"}">{html.escape(line)}</text>')
            parts.append(f'<line x1="{x}" y1="202" x2="{x}" y2="{bottom}" stroke="#888" stroke-dasharray="8 7" stroke-width="1.2"/>')
            events=[top+mi*row for mi,(a,b,c) in enumerate(panel) if idx in (a,b)]
            if idx and events:
                parts.append(f'<rect x="{x-6}" y="{min(events)}" width="12" height="{max(45,max(events)-min(events)+22)}" fill="{yellow}" stroke="{red}" stroke-width="1.3"/>')
        for mi,(sender,receiver,label) in enumerate(panel):
            yy=top+mi*row;x1,x2=xs[sender],xs[receiver]
            returned=receiver<sender and sender!=receiver
            dash=' stroke-dasharray="6 5"' if returned else ''
            marker='return' if returned else 'call'
            if sender==receiver:
                parts.append(f'<path d="M{x1+6},{yy} h80 v36 h-80" fill="none" stroke="{red}" stroke-width="1.5" marker-end="url(#call)"/>')
                tx=x1+60;anchor='middle';label_width=30
            else:
                parts.append(f'<line x1="{x1}" y1="{yy+28}" x2="{x2}" y2="{yy+28}" stroke="{red}" stroke-width="1.5"{dash} marker-end="url(#{marker})"/>')
                tx=(x1+x2)/2;anchor='middle';label_width=36 if abs(x2-x1)>400 else 25
            lines=textwrap.wrap(str(offset+mi+1)+': '+label,label_width,break_long_words=False)
            for li,line in enumerate(lines):
                parts.append(f'<text x="{tx}" y="{yy-16+li*24}" text-anchor="{anchor}" font-family="Times New Roman" font-size="23">{html.escape(line)}</text>')
        parts.append(f'<text x="600" y="{height-22}" text-anchor="middle" font-family="Times New Roman" font-size="22">{html.escape(key)} — Phần {part}/{parts_count} — Thứ tự thông điệp liên tục</text></svg>')
        (directory/(panel_key+'.svg')).write_text(''.join(parts))
        diagrams.append(dict(id=panel_key,title=title+f' — phần {part}/{parts_count}',kind='sequence',description=note,source='backend/src/'+source,refs=refs,base_id=key,message_offset=offset,messages=panel))
for sequence in SEQUENCES:sequence_svg(sequence)

lines=dot_base();lines[1]='graph [bgcolor="white",rankdir=TB,nodesep=0.4,ranksep=0.5,pad=0.2];'
for key,label in [('r','receipt01: BillingReceipt\namount=3.000.000; available=500.000'),('a','alloc01: PaymentAllocation\namount=2.500.000; releasedAt=null'),('p','payment01: Payment\namount=2.500.000; type=PAYMENT'),('i','invoice01: Invoice\ntotalAmount=4.000.000\npaidAmount=2.500.000; status=PARTIAL'),('t','tenant01: Tenant\nHồ sơ giả định, không phải dữ liệu thật')]:lines.append(f'{key} [shape=box,label={dotq(label)}];')
for edge in ['r -> a [label="allocations"];','a -> p [label="payment"];','a -> i [label="invoice"];','r -> t [label="tenant"];','i -> t [label="tenant"];']:lines.append(edge)
register('OD-01','Đối tượng khoản thu và hóa đơn thanh toán một phần',lines,'object','Ví dụ giả định: 3.000.000 đồng nhận, 2.500.000 phân bổ, 500.000 còn khả dụng; công nợ hóa đơn còn 1.500.000 đồng.')

(OUT/'diagram-manifest.json').write_text(json.dumps(diagrams,ensure_ascii=False,indent=2))
print('Diagram sources:',len(diagrams),dict(__import__('collections').Counter(d['kind'] for d in diagrams)))
