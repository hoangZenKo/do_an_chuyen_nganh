from pathlib import Path
import json
import re
import sys

import pdfplumber
from PIL import Image, ImageDraw

WORK=Path('/Users/hoang/Rental_room_management/BA_Documentation/07_Report_Completion')

def main():
    directory=Path(sys.argv[1])
    images=sorted(directory.glob('page-*.png'),key=lambda path:int(path.stem.split('-')[-1]))
    outside=[];empty=[];examples={};all_text=[]
    with pdfplumber.open(next(directory.glob('*.pdf'))) as document:
        for index,page in enumerate(document.pages,1):
            text=page.extract_text() or ''
            all_text.append(text)
            if not text.strip() and not page.images:
                empty.append(index)
            bad=[char['text'] for char in page.chars if char.get('text','').strip() and (char['x0'] < -1 or char['x1'] > page.width+1 or char['top'] < -1 or char['bottom'] > page.height+1)]
            if bad:
                outside.append({'page':index,'characters':bad[:20]})
            if 'Đặc tả nghiệp vụ UC-' in text:
                examples.setdefault('specification',index)
            if 'Hình 2.8 G04' in text:
                examples['diagram']=index
            if text.startswith('Phụ lục B') or '\nPhụ lục B' in text:
                examples['matrix']=index
            page.flush_cache()
        count=len(document.pages)
    for offset in range(0,len(images),48):
        canvas=Image.new('RGB',(1200,2376),'#cccccc')
        draw=ImageDraw.Draw(canvas)
        for index,path in enumerate(images[offset:offset+48]):
            with Image.open(path) as original:
                thumb=original.convert('RGB')
            thumb.thumbnail((195,272))
            left=index%6*200;top=index//6*297
            canvas.paste(thumb,(left,top+20))
            draw.text((left+4,top+3),str(offset+index+1),fill='black')
        canvas.save(directory/('contact-'+str(offset//48+1)+'.jpg'))
    result={'pdfPageCount':count,'pageImageCount':len(images),'blankPages':empty,'textOutsidePage':outside,'representativePages':examples,'contactSheets':(len(images)+47)//48,'scope':'Kiểm tra khung trang và tạo ảnh tổng quan; cần đọc ảnh để đánh giá bố cục, không thay thế nghiệm thu nghiệp vụ.'}
    (WORK/'data/layout-validation.json').write_text(json.dumps(result,ensure_ascii=False,indent=2))
    print(json.dumps(result,ensure_ascii=False,indent=2))
    assert count==len(images) and not empty and not outside

if __name__=='__main__':main()
