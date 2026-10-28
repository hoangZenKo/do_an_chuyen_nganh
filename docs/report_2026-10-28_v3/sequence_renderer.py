import html
import json
import re
from pathlib import Path
from PIL import ImageFont
from sequence_model import MODELS, save

WIDTH = 1300
FONT_SIZE = 25
FONT = ImageFont.truetype('/System/Library/Fonts/Supplemental/Times New Roman.ttf', FONT_SIZE)
YELLOW = '#FFFFB9'
RED = '#800000'

def esc(value):
    return html.escape(str(value))

def lines_for(text, maximum=1180):
    lines=[]
    current=''
    for word in text.split():
        candidate=(current+' '+word).strip()
        if current and FONT.getlength(candidate)>maximum:
            lines.append(current)
            current=word
        else:
            current=candidate
    if current:
        lines.append(current)
    return lines

def render(model, directory, refs):
    participants=model['participants']
    actors=[part for part in participants if part['kind']=='actor']
    participants=actors+[part for part in participants if part['kind']!='actor']
    xs={part['id']:85+index*1130/(len(participants)-1) for index,part in enumerate(participants)}
    messages=[]
    frames=[]
    sequence=0
    def layout(events,y,depth=0,context=()):
        nonlocal sequence
        for event in events:
            if event['type']=='message':
                sequence+=1
                label=f'{sequence}. {event["text"]}'
                label_lines=lines_for(label)
                baseline=y+22
                arrow_y=baseline+27*(len(label_lines)-1)+9
                messages.append(dict(event,number=sequence,lines=label_lines,baseline=baseline,y=arrow_y,depth=depth,context=context))
                y=arrow_y+16
            else:
                top=y
                guard_lines=lines_for('['+event['guard']+']',1080-depth*24)
                y+=29*len(guard_lines)+8
                branch_id=len(frames)+sequence+1000
                y=layout(event['children'],y,depth+1,context+(branch_id,0))
                alternate=event.get('alternate')
                divider=None
                if alternate:
                    divider=y
                    alt_lines=lines_for('['+alternate[0]+']',1080-depth*24)
                    y+=29*len(alt_lines)+8
                    y=layout(alternate[1],y,depth+1,context+(branch_id,1))
                frames.append(dict(top=top,bottom=y+5,depth=depth,kind=event['kind'],guards=guard_lines,divider=divider,alt_lines=alt_lines if alternate else []))
                y+=16
        return y
    bottom=layout(model['events'],180)+18
    height=bottom+20
    parts=[f'<svg xmlns="http://www.w3.org/2000/svg" width="{WIDTH}" height="{height}" viewBox="0 0 {WIDTH} {height}">',
        '<rect width="100%" height="100%" fill="white"/>',
        '<defs><marker id="call" markerWidth="9" markerHeight="9" refX="8" refY="4" orient="auto"><path d="M0,0 L8,4 L0,8 Z" fill="#800000"/></marker><marker id="return" markerWidth="10" markerHeight="10" refX="9" refY="4" orient="auto"><path d="M0,0 L9,4 L0,8" fill="none" stroke="#800000" stroke-width="1.5"/></marker></defs>']
    def text(x,y,value,size=FONT_SIZE,anchor='start',bold=False,underline=False):
        parts.append(f'<text x="{x}" y="{y}" text-anchor="{anchor}" font-family="Times New Roman" font-size="{size}" font-weight="{"bold" if bold else "normal"}" text-decoration="{"underline" if underline else "none"}">{esc(value)}</text>')
    for frame in sorted(frames,key=lambda item:item['depth']):
        left=18+frame['depth']*12
        right=WIDTH-18-frame['depth']*12
        parts.append(f'<rect x="{left}" y="{frame["top"]}" width="{right-left}" height="{frame["bottom"]-frame["top"]}" fill="none" stroke="#696969" stroke-width="1.1"/>')
        parts.append(f'<path d="M{left},{frame["top"]} h75 v24 l-12,9 h-63 z" fill="{YELLOW}" stroke="{RED}" stroke-width="1.1"/>')
        text(left+9,frame['top']+24,frame['kind'],23,bold=True)
        for index,line in enumerate(frame['guards']):
            text(left+86,frame['top']+25+index*29,line,24)
        if frame['divider'] is not None:
            parts.append(f'<line x1="{left}" y1="{frame["divider"]}" x2="{right}" y2="{frame["divider"]}" stroke="#696969" stroke-dasharray="7 5"/>')
            for index,line in enumerate(frame['alt_lines']):
                text(left+86,frame['divider']+25+index*29,line,24)
    for participant in participants:
        horizontal=xs[participant['id']]
        kind=participant['kind']
        if kind=='actor':
            parts.append(f'<circle cx="{horizontal}" cy="33" r="12" fill="{YELLOW}" stroke="{RED}" stroke-width="1.6"/><path d="M{horizontal},45 v34 m-26,-23 h52 m-26,23 l-23,27 m23,-27 l23,27" fill="none" stroke="{RED}" stroke-width="1.7"/>')
        elif kind=='boundary':
            parts.append(f'<circle cx="{horizontal}" cy="54" r="29" fill="{YELLOW}" stroke="{RED}" stroke-width="1.7"/><path d="M{horizontal-43},27 v54 m0,-27 h14" fill="none" stroke="{RED}" stroke-width="1.7"/>')
        elif kind=='control':
            parts.append(f'<circle cx="{horizontal}" cy="54" r="29" fill="{YELLOW}" stroke="{RED}" stroke-width="1.7"/><path d="M{horizontal+9},20 l-17,5 l14,12" fill="none" stroke="{RED}" stroke-width="1.7"/>')
        else:
            parts.append(f'<path d="M{horizontal-32},33 v43 a32,10 0 0 0 64,0 V33" fill="{YELLOW}" stroke="{RED}" stroke-width="1.7"/><ellipse cx="{horizontal}" cy="33" rx="32" ry="10" fill="{YELLOW}" stroke="{RED}" stroke-width="1.7"/>')
        labels=lines_for(participant['name'],250)
        for index,line in enumerate(labels):
            text(horizontal,128+27*index,line,25,'middle',underline=kind!='actor')
        parts.append(f'<line x1="{horizontal}" y1="{147+27*(len(labels)-1)}" x2="{horizontal}" y2="{bottom}" stroke="#8A8A8A" stroke-dasharray="7 6" stroke-width="1.2"/>')
    for index,item in enumerate(messages):
        if item['kind']=='return' or item['receiver'] in [part['id'] for part in actors]:
            continue
        receiver=xs[item['receiver']]
        end=item['y']+14
        if item['sender']!=item['receiver']:
            for candidate in messages[index+1:]:
                if candidate['kind']=='return' and candidate['sender']==item['receiver'] and candidate['receiver']==item['sender'] and candidate['context']==item['context']:
                    end=candidate['y']+2
                    break
        offset=6 if item['sender']==item['receiver'] else 0
        parts.append(f'<rect x="{receiver-6+offset}" y="{item["y"]-2}" width="12" height="{end-item["y"]+2}" fill="{YELLOW}" stroke="{RED}" stroke-width="1.1"/>')
    for item in messages:
        sender=xs[item['sender']]
        receiver=xs[item['receiver']]
        vertical=item['y']
        returned=item['kind']=='return'
        dash=' stroke-dasharray="7 5"' if returned else ''
        marker='return' if returned else 'call'
        if sender==receiver:
            direction=-1 if sender>1000 else 1
            parts.append(f'<path d="M{sender+6},{vertical-4} h{direction*75} v13 h{-direction*75}" fill="none" stroke="{RED}" stroke-width="1.4" marker-end="url(#{marker})"/>')
        else:
            parts.append(f'<line x1="{sender}" y1="{vertical}" x2="{receiver}" y2="{vertical}" stroke="{RED}" stroke-width="1.4"{dash} marker-end="url(#{marker})"/>')
        for index,line in enumerate(item['lines']):
            text_width=FONT.getlength(line)
            center=max(47+text_width/2,min(WIDTH-47-text_width/2,(sender+receiver)/2))
            baseline=item['baseline']+index*27
            parts.append(f'<rect x="{center-text_width/2-3}" y="{baseline-22}" width="{text_width+6}" height="25" fill="white"/>')
            text(center,baseline,line,anchor='middle')
    parts.append('</svg>')
    path=directory/(model['id']+'.svg')
    path.write_text(''.join(parts))
    model['render']=dict(width=WIDTH,height=height,messages=len(messages),fragments=len(frames),font_size=FONT_SIZE)
    return dict(id=model['id'],title=model['title'],kind='sequence',refs=refs,source='; '.join('backend/src/'+path+':'+method for path,method in model['methods']),description=model['post'],pre=model['pre'],messages=messages,fragments=frames,width=WIDTH,height=height)

def render_all(directory, legacy_sequences):
    references={row[0]:row[2] for row in legacy_sequences}
    result=[render(model,directory,references[key]) for key,model in MODELS.items()]
    save(directory.parent/'sequence-model.json')
    return result
