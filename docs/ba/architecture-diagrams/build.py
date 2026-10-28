import json
import subprocess
import xml.etree.ElementTree as ET
from pathlib import Path
from PIL import ImageFont

BASE = Path(__file__).resolve().parent
WIDTH, HEIGHT = 1500, 1500
STROKE, FILL = '#800000', '#FFFFB9'
FONT = '/System/Library/Fonts/Supplemental/Tahoma.ttf'
shapes, texts = [], []
root = ET.Element('mxfile', host='app.diagrams.net', type='device')
diagram = ET.SubElement(root, 'diagram', id='architecture-overview', name='Kiến trúc tổng thể')
graph = ET.SubElement(diagram, 'mxGraphModel', page='1', pageWidth=str(WIDTH), pageHeight=str(HEIGHT), grid='1', gridSize='10')
cells = ET.SubElement(graph, 'root')
ET.SubElement(cells, 'mxCell', id='0')
ET.SubElement(cells, 'mxCell', id='1', parent='0')
counter = 1

def cell(value, style, x, y, width, height):
    global counter
    counter += 1
    element = ET.SubElement(cells, 'mxCell', id=str(counter), value=value, style=style, vertex='1', parent='1')
    ET.SubElement(element, 'mxGeometry', x=str(x), y=str(y), width=str(width), height=str(height), attrib={'as':'geometry'})
    return element

def box(x, y, width, height, fill=FILL, dashed=False):
    shapes.append(f'<rect x="{x}" y="{y}" width="{width}" height="{height}" fill="{fill}" stroke="{STROKE}" stroke-width="1.6"'+(' stroke-dasharray="7 5"' if dashed else '')+'/>')
    cell('', f'rounded=0;fillColor={fill};strokeColor={STROKE};strokeWidth=1.6;dashed={int(dashed)};', x,y,width,height)

def text(label, x, y, width, size=22, bold=False, align='center'):
    bold = bool(bold)
    lines = label.split('\n')
    font = ImageFont.truetype(FONT,size)
    assert all(font.getlength(line) < width-8 for line in lines), (label,width)
    height = len(lines)*(size+8)
    assert x>=0 and x+width<=WIDTH and y>=0 and y+height<=HEIGHT
    anchor = 'middle' if align=='center' else 'start'
    position = x+width/2 if align=='center' else x+4
    node = ET.Element('text', x=str(position), y=str(y+size), fill='#181818', attrib={'font-family':'Tahoma, sans-serif','font-size':str(size),'text-anchor':anchor})
    if bold: node.set('font-weight','bold')
    for index,line in enumerate(lines):
        span=ET.SubElement(node,'tspan',x=str(position),dy='0' if index==0 else str(size+8))
        span.text=line
    shapes.append(ET.tostring(node,encoding='unicode'))
    cell(label,f'text;html=0;strokeColor=none;fillColor=none;align={align};verticalAlign=top;fontFamily=Tahoma;fontSize={size};fontColor=#181818;fontStyle={int(bold)};spacing=0;whiteSpace=wrap;',x,y,width,height)
    texts.append(label)

def line(points, arrow=True, dashed=False):
    global counter
    path='M '+' L '.join(f'{x} {y}' for x,y in points)
    shapes.append(f'<path d="{path}" fill="none" stroke="{STROKE}" stroke-width="1.7"'+(' marker-end="url(#arrow)"' if arrow else '')+(' stroke-dasharray="7 5"' if dashed else '')+'/>')
    counter+=1
    element=ET.SubElement(cells,'mxCell',id=str(counter),edge='1',parent='1',style=f'edgeStyle=none;rounded=0;endArrow={"block" if arrow else "none"};endFill=1;strokeColor={STROKE};strokeWidth=1.7;dashed={int(dashed)};')
    geometry=ET.SubElement(element,'mxGeometry',relative='1',attrib={'as':'geometry'})
    ET.SubElement(geometry,'mxPoint',x=str(points[0][0]),y=str(points[0][1]),attrib={'as':'sourcePoint'})
    ET.SubElement(geometry,'mxPoint',x=str(points[-1][0]),y=str(points[-1][1]),attrib={'as':'targetPoint'})
    if len(points)>2:
        waypoints=ET.SubElement(geometry,'Array',attrib={'as':'points'})
        for x,y in points[1:-1]: ET.SubElement(waypoints,'mxPoint',x=str(x),y=str(y))

def actor(name,x):
    shapes.append(f'<circle cx="{x}" cy="117" r="12" fill="{FILL}" stroke="{STROKE}" stroke-width="1.6"/>')
    cell('',f'ellipse;fillColor={FILL};strokeColor={STROKE};',x-12,105,24,24)
    for points in [[(x,129),(x,155)],[(x-20,140),(x+20,140)],[(x,155),(x-18,175)],[(x,155),(x+18,175)]]: line(points,False)
    text(name,x-125,177,250,22,True)

text('KIẾN TRÚC TỔNG THỂ HỆ THỐNG QUẢN LÝ NHÀ TRỌ',60,25,1380,29,True)
text('Mô hình client–server · Backend nguyên khối mô-đun (modular monolith)',60,68,1380,21)
for name,position in [('Admin',230),('Chủ trọ',600),('Người thuê',970)]: actor(name,position)
for position in [230,600,970]: line([(position,211),(position,226)],False)
line([(230,226),(970,226)],False)
line([(600,226),(600,265)])

box(80,265,1040,225,'#FFFFFF')
text('ỨNG DỤNG FLUTTER',100,279,1000,25,True)
for x,title,description in [(110,'Giao diện người dùng','Màn hình theo vai trò'),(450,'Quản lý trạng thái','Riverpod'),(790,'Truy cập dữ liệu','Repository · Dio')]:
    box(x,340,300,105)
    text(title,x+8,354,284,22,True)
    text(description,x+8,394,284,20)
line([(410,392),(450,392)])
line([(750,392),(790,392)])
text('Dữ liệu hiển thị và chức năng được giới hạn theo quyền người dùng',105,456,990,18)
line([(940,490),(940,575)])
text('REST API · JSON · JWT',610,514,310,21)

box(80,575,1040,650,'#FFFFFF')
text('BACKEND NESTJS',100,588,1000,25,True)
text('Các mô-đun cùng thuộc một ứng dụng backend, không phải các dịch vụ độc lập',100,628,1000,18)
box(110,675,980,90)
text('API · Controllers · Guards · Validation',125,685,950,23,True)
text('Tiếp nhận yêu cầu · Xác thực · Phân quyền · Kiểm tra dữ liệu',125,724,950,21)
line([(600,765),(600,818)])
text('Các mô-đun nghiệp vụ / Services',110,780,445,21,True,'left')
box(105,818,990,230,'#FFFFFF')
modules=[('Khu trọ và phòng','Properties · Rooms'),('Người thuê và hợp đồng','Tenants · Leases'),('Hóa đơn và thanh toán','Billing'),('Bảo trì và chi phí','Maintenance · Expenses'),('Tổng quan và báo cáo','Dashboard · Reports'),('Thông báo và nhật ký','Notifications · Audit')]
for index,(title,detail) in enumerate(modules):
    x=125+(index%3)*320
    y=835+(index//3)*105
    box(x,y,300,90)
    text(title,x+5,y+10,290,20,True)
    text(detail,x+5,y+48,290,18)
line([(430,1048),(430,1100)])
box(110,1100,625,80)
text('Prisma ORM',120,1110,605,23,True)
text('Truy cập dữ liệu quan hệ',120,1148,605,20)
box(790,1100,300,80)
text('UploadsController',800,1110,280,21,True)
text('Tiếp nhận tệp tải lên',800,1148,280,19)
line([(1090,720),(1107,720),(1107,1083),(940,1083),(940,1100)])
text('Các mô-đun khác: Auth · Admin · TenantPortal',480,1192,610,18)

box(1190,935,270,115,'#FFFFFF',True)
text('Dịch vụ Zalo ZNS',1200,947,250,22,True)
text('Tùy chọn khi bật\nvà cấu hình hợp lệ',1200,986,250,19)
line([(1065,980),(1190,980)],True,True)
text('Gửi tin',1109,948,80,17)

box(1190,1100,270,130)
text('Kho tệp máy chủ',1200,1112,250,21,True)
text('Ảnh và tài liệu\nThư mục uploads',1200,1153,250,19)
line([(1090,1140),(1190,1140)])
text('Lưu tệp',1102,1109,85,17)

line([(430,1180),(430,1288)])
text('Đọc / ghi dữ liệu',445,1248,280,20,'', 'left')
shapes.append(f'<path d="M 180 1310 A 250 22 0 0 1 680 1310 L 680 1380 A 250 22 0 0 1 180 1380 Z" fill="{FILL}" stroke="{STROKE}" stroke-width="1.7"/>')
shapes.append(f'<ellipse cx="430" cy="1310" rx="250" ry="22" fill="{FILL}" stroke="{STROKE}" stroke-width="1.7"/>')
cell('',f'shape=cylinder;boundedLbl=1;backgroundOutline=1;fillColor={FILL};strokeColor={STROKE};size=22;',180,1288,500,114)
text('Cơ sở dữ liệu PostgreSQL',195,1335,470,23,True)
text('Hợp đồng · Hóa đơn · Thanh toán · Dữ liệu quản lý',740,1297,710,20)
text('Client không truy cập trực tiếp cơ sở dữ liệu',740,1334,710,20)
line([(90,1440),(155,1440)])
text('Hướng yêu cầu / truy cập chính; phản hồi được lược bớt',170,1427,720,18,'','left')
line([(940,1440),(1005,1440)],True,True)
text('Tích hợp tùy chọn',1020,1427,400,18,'','left')
text('Sơ đồ logic tổng thể; không mô tả vị trí triển khai máy chủ hoặc mọi lời gọi nội bộ.',80,1460,1380,17)

svg='<svg xmlns="http://www.w3.org/2000/svg" width="1500" height="1500" viewBox="0 0 1500 1500"><title>Kiến trúc tổng thể hệ thống quản lý nhà trọ</title><defs><marker id="arrow" markerWidth="8" markerHeight="8" refX="7" refY="4" orient="auto"><path d="M0,0 L8,4 L0,8 Z" fill="#800000"/></marker></defs><rect width="1500" height="1500" fill="white"/>'+''.join(shapes)+'</svg>'
(BASE/'architecture-overview.svg').write_text(svg,encoding='utf8')
ET.ElementTree(root).write(BASE/'architecture-overview.drawio',encoding='utf-8',xml_declaration=True)
node='/Users/hoang/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/bin/node'
sharp='/Users/hoang/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/sharp'
subprocess.run([node,'-e',"const sharp=require(process.argv[1]);sharp(process.argv[2],{density:144}).flatten({background:'#ffffff'}).removeAlpha().png().toFile(process.argv[3]).catch(e=>{console.error(e);process.exit(1)});",sharp,str(BASE/'architecture-overview.svg'),str(BASE/'architecture-overview.png')],check=True)
print(json.dumps({'labels':len(texts),'drawioCells':len(cells),'width':WIDTH,'height':HEIGHT,'result':'PASS'},ensure_ascii=False))

