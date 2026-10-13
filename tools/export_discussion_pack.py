#!/usr/bin/env python3
"""Export a static discussion diagram and offline ballot; no network or collected votes.

Only PNG generation needs Pillow. SVG/HTML use standard library.
"""
import argparse
import html
import os
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]
PALETTE = {
    'teal': ('#E1F5EE', '#0F6E56', '#085041'),
    'blue': ('#E6F1FB', '#185FA5', '#0C447C'),
    'amber': ('#FAEEDA', '#854F0B', '#633806'),
}
NODES = [
    (40, 84, 'teal', '世界观起点', ['世界石化，我率先苏醒', '范围、原因、复苏仍未定']),
    (40, 218, 'blue', '体验偏好 Q01 / Q07', ['收集构筑 / 冒险剧情', '操作挑战 / 风险撤离', '选最重要的两种体验']),
    (40, 352, 'blue', '画面候选 Q04', ['卡通科技水墨 / 像素', 'HD-2D / 其他', '先比较样张，不批量生产']),
    (448, 84, 'amber', '操作路线 Q02 / Q03', ['布阵自动 / 自动加指令', '逐单位回合 / 实时主角', '视角另选，操作尚未定']),
    (448, 218, 'amber', '远征与模式 Q05 / Q06', ['单机 / 合作 / 对抗', '搜寻、战斗、撤离与入库', '失败能丢什么，仍需选择']),
    (448, 352, 'amber', '下一步交付 Q08', ['样张 / 战斗 / 一局 / 剧情', '先收偏好，分歧用实验验证', '确认后才成为制作任务']),
]


def curves():
    result = []
    for x, y, *_ in NODES:
        start_x = 264 if x < 300 else 416
        end_x = x + 192 if x < 300 else x
        bend = 248 if x < 300 else 432
        result.append(((start_x, 242), (bend, 242), (bend, y + 42), (end_x, y + 42)))
    return result


def svg_source():
    esc = html.escape
    parts = ['<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 680 480" width="680" height="480" role="img" aria-label="Cun候选方向讨论导图">',
             '<style>text{font-family:-apple-system,\'PingFang SC\',\'Microsoft YaHei\',sans-serif;text-anchor:middle;dominant-baseline:central}</style>',
             '<rect width="680" height="480" fill="#FFFFFF"/>',
             '<text x="340" y="30" font-size="14" font-weight="500" fill="#0C447C">Cun · 团队方向讨论</text>',
             '<text x="340" y="52" font-size="11" font-weight="400" fill="#0C447C">候选不是定案｜绿：用户前提　蓝：讨论候选　橙：待选择</text>']
    for points in curves():
        a, b, c, d = points
        parts.append(f'<path d="M{a[0]} {a[1]} C{b[0]} {b[1]} {c[0]} {c[1]} {d[0]} {d[1]}" fill="none" stroke="#85B7EB" stroke-width="1"/>')
    for x, y, family, title, lines in NODES:
        fill, stroke, color = PALETTE[family]
        parts.append(f'<rect x="{x}" y="{y}" width="192" height="84" rx="10" fill="{fill}" stroke="{stroke}" stroke-width="0.8"/>')
        parts.append(f'<text x="{x+96}" y="{y+18}" font-size="13" font-weight="500" fill="{color}">{esc(title)}</text>')
        for i, line in enumerate(lines):
            parts.append(f'<text x="{x+96}" y="{y+38+i*17}" font-size="11" font-weight="400" fill="{color}">{esc(line)}</text>')
    parts.extend(['<rect x="264" y="212" width="152" height="60" rx="12" fill="#E1F5EE" stroke="#0F6E56" stroke-width="1"/>',
                  '<text x="340" y="233" font-size="14" font-weight="500" fill="#085041">石化世界</text>',
                  '<text x="340" y="253" font-size="13" font-weight="400" fill="#085041">异灵卡牌冒险？</text>',
                  '<text x="340" y="458" font-size="11" font-weight="400" fill="#0C447C">先答8题 → 保留分歧 → 做小实验 → 明确确认｜新点子持续收录</text>',
                  '</svg>'])
    return '\n'.join(parts) + '\n'


def png_image(output, font_path):
    from PIL import Image, ImageDraw, ImageFont
    scale = 4
    image = Image.new('RGB', (680 * scale, 480 * scale), 'white')
    draw = ImageDraw.Draw(image)
    fonts = {size: ImageFont.truetype(str(font_path), size * scale) for size in (11, 13, 14)}
    def text(x, y, value, size, color):
        font = fonts[size]
        if draw.textlength(value, font=font) > 192 * scale - 20 * scale and x != 340:
            raise ValueError('Diagram node text is too long: ' + value)
        draw.text((x*scale, y*scale), value, font=font, fill=color, anchor='mm')
    def box(x, y, w, h, fill, stroke, radius=10):
        draw.rounded_rectangle((x*scale, y*scale, (x+w)*scale, (y+h)*scale), radius=radius*scale, fill=fill, outline=stroke, width=3)
    text(340, 30, 'Cun · 团队方向讨论', 14, '#0C447C')
    text(340, 52, '候选不是定案｜绿：用户前提　蓝：讨论候选　橙：待选择', 11, '#0C447C')
    for a, b, c, d in curves():
        points = []
        for step in range(65):
            t = step / 64
            points.append((( (1-t)**3*a[0] + 3*(1-t)**2*t*b[0] + 3*(1-t)*t*t*c[0] + t**3*d[0])*scale,
                           ( (1-t)**3*a[1] + 3*(1-t)**2*t*b[1] + 3*(1-t)*t*t*c[1] + t**3*d[1])*scale))
        draw.line(points, fill='#85B7EB', width=scale)
    for x, y, family, title, lines in NODES:
        fill, stroke, color = PALETTE[family]
        box(x, y, 192, 84, fill, stroke)
        text(x+96, y+18, title, 13, color)
        for i, line in enumerate(lines): text(x+96, y+38+i*17, line, 11, color)
    box(264, 212, 152, 60, '#E1F5EE', '#0F6E56', 12)
    text(340, 233, '石化世界', 14, '#085041')
    text(340, 253, '异灵卡牌冒险？', 13, '#085041')
    text(340, 458, '先答8题 → 保留分歧 → 做小实验 → 明确确认｜新点子持续收录', 11, '#0C447C')
    image.save(output)


def ballot_questions(source):
    result = []
    for match in re.finditer(r'^## (Q\d{2}) (.+?)\n(.*?)(?=^## |\Z)', source, re.M | re.S):
        qid, title, body = match.groups()
        if int(qid[1:]) > 8: continue
        options = re.findall(r'^- ([A-G])：(.*)$', body, re.M)
        notes = [line for line in body.splitlines() if line and not line.startswith('- ')]
        result.append((qid, title, options, notes))
    if len(result) != 8 or any(not q[2] for q in result):
        raise ValueError('Expected Q01-Q08 ballot options')
    return result


def question_rows(source):
    rows = []
    for line in source.splitlines():
        if re.match(r'^\| Q\d{2} \|', line):
            cells = [c.strip() for c in line.strip('|').split('|')]
            if len(cells) != 4: raise ValueError('Invalid question table row')
            rows.append(cells)
    if len(rows) != 40 or len({r[0] for r in rows}) != 40:
        raise ValueError('Expected 40 unique questions')
    return rows


def offline_html(svg, ballots, questions):
    esc = html.escape
    sections = []
    for qid, title, options, notes in ballots:
        kind = 'checkbox' if qid in ('Q01', 'Q07') else 'radio'
        opts = ''.join(f'<label><input type="{kind}" name="{qid}" value="{letter}"> <strong>{letter}</strong>：{esc(label)}</label>' for letter, label in options)
        info = ''.join('<p class="note">'+esc(n)+'</p>' for n in notes)
        if qid in ('Q01', 'Q07'):
            info += '<p class="note">最多勾选两项；本页不自动校验数量或记录先后。请在下面理由栏写“首选 → 次选”。</p>'
        sections.append(f'<fieldset><legend>{qid} {esc(title)}</legend>{opts}{info}<label class="note">其他/理由（可空）<textarea aria-label="{qid}理由" rows="2"></textarea></label></fieldset>')
    rows = ''.join('<tr>'+''.join('<td>'+esc(c)+'</td>' for c in row)+'</tr>' for row in questions)
    response = '昵称/代号：\n' + '\n'.join(q[0] + '：' for q in ballots) + '\n最不能接受的一件事：\n新想法：\n想先看到什么：\n自愿参与方向/可投入时间：'
    return '''<!doctype html>
<html lang="zh-CN"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>Cun团队方向讨论与选择票</title><style>
*{box-sizing:border-box}body{margin:0;background:#f5f8fb;color:#17344b;font:16px/1.7 system-ui,'Microsoft YaHei',sans-serif}main{max-width:960px;margin:auto;padding:28px}h1{font-size:28px}h2{margin-top:34px;font-size:22px}.card,fieldset{background:white;border:1px solid #cbd9e5;border-radius:12px;padding:22px;margin:18px 0}.banner{background:#faeeda;border-left:4px solid #854f0b;padding:14px}svg{display:block;width:100%;height:auto;max-height:480px}legend{font-weight:600;padding:0 8px}label{display:block;padding:6px 0}input[type=radio],input[type=checkbox]{width:18px;height:18px;vertical-align:middle;margin-right:5px}input[type=text],textarea{width:100%;font:inherit;border:1px solid #b6c8d9;border-radius:6px;padding:8px;background:#fff;color:#17344b}.note{font-size:14px;color:#445c70}.table-wrap{overflow-x:auto}table{border-collapse:collapse;width:100%;font-size:14px}td,th{border:1px solid #cbd9e5;padding:10px;text-align:left;vertical-align:top}th{background:#e6f1fb}pre{white-space:pre-wrap;font:inherit;background:#f3f6f9;padding:15px}details{margin:24px 0}summary{cursor:pointer;font-size:20px;font-weight:600} @media print{body{background:white}main{max-width:none;padding:0}fieldset,.card{break-inside:avoid}details{display:block}svg{max-height:400px}.banner{border:1px solid #b6c8d9}.note{color:#333}textarea{min-height:3em}table{font-size:11px}}
</style></head><body><main>
<h1>Cun · 大家想做的是同一款游戏吗？</h1>
<div class="banner"><strong>候选方向讨论，不是定案或开工单。</strong><br>世界观起点：“全世界都变成了石头，我复活了”。具体规则、操作和美术仍未确定。此页没有成员姓名、聊天截图或真实票数。</div>
<section class="card"><h2>先看主干，不用先读长策划</h2>SVG_DIAGRAM<p>收集与构筑、冒险与剧情、风险与撤离，是讨论过的体验；战斗操作仍有多种路线。新点子继续收录，不因为暂时不做就丢掉。</p></section>
<h2>八题可选辅助：当前各自和自己的Agent梳理</h2><p>主入口是项目中的完整Agent讨论材料：自包含背景与40题候选、取舍、建议。每人自己讨论、自己总结、自己看，不要求集中填票或发回。本页只作简短辅助。Q01/Q07最多选两项；其他单选，可留空、选其他或暂不确定。<strong>本页离线、无脚本、无提交按钮、不保存或上传任何答案。</strong>如需保留自己的选择，请打印为PDF或自行记录。</p>
<label>昵称/自定代号（不需要真名）<input type="text" aria-label="昵称或代号"></label>
BALLOTS
<fieldset><legend>补充意见（都可空）</legend><label>最不能接受的一件事<textarea rows="2"></textarea></label><label>最想加的一个奇思妙想<textarea rows="2"></textarea></label><label>不确定时想先看到什么<textarea rows="2"></textarea></label><label>愿意参与什么/可投入时间（自愿，不作任务承诺）<textarea rows="2"></textarea></label></fieldset>
<h2>个人简短记录格式（可选，不要求提交）</h2><pre>RESPONSE</pre>
<section class="card"><h2>个人总结不等于团队定案</h2><p>Agent只能整理本人实际表达的想法，未讨论项保持不确定，不能把材料建议填成个人答案。不要求回收、不读取伙伴的私人对话；只有本人愿意才分享摘要。实际团队确认时再记录范围、确认者和复议条件。</p><p>预算、权利、外发、部署和发布另需明确授权，不能通过个人选择绕过。</p><p><strong>个人答案：尚未填写。团队确认结果：无。</strong>本页不会生成或统计任何票数。</p></section>
<details><summary>其余问题总览：目前共40项，分轮处理</summary><p>第一轮Q01–Q08对齐方向；第二轮Q09–Q31细化设计；第三轮Q32–Q40安排实施与合作。不要求一次回答全部。</p><div class="table-wrap"><table><thead><tr><th>ID</th><th>问题</th><th>候选/条件</th><th>影响/决定方式</th></tr></thead><tbody>QUESTIONS</tbody></table></div></details>
<p class="note">规划版本v0.1｜本页为自包含离线转发副本。项目中以想法池、问题总表、选择票和讨论说明为维护源；修改源文档后需要重新导出。本次未推送远端、未创建在线投票服务。</p>
</main></body></html>'''.replace('SVG_DIAGRAM', svg).replace('BALLOTS', '\n'.join(sections)).replace('RESPONSE', esc(response)).replace('QUESTIONS', rows)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--font', type=Path, default=None, help='Local CJK font for PNG; on Windows defaults to Microsoft YaHei')
    parser.add_argument('--skip-png', action='store_true')
    args = parser.parse_args()
    out = ROOT / 'share'
    out.mkdir(exist_ok=True)
    svg = svg_source()
    (out / 'cun-discussion-map.svg').write_text(svg, encoding='utf-8')
    if not args.skip_png:
        default_font = Path(os.environ.get('WINDIR', 'C:/Windows')) / 'Fonts/msyh.ttc'
        font = args.font or default_font
        if not font.is_file(): raise ValueError('Pass --font with a local CJK font, or use --skip-png')
        png_image(out / 'cun-discussion-map.png', font)
    ballot_source = (ROOT / 'docs/design/ballot-round-1.md').read_text(encoding='utf-8')
    ballots = ballot_questions(ballot_source)
    questions = question_rows((ROOT / 'docs/design/questions.md').read_text(encoding='utf-8'))
    (out / 'team-discussion.html').write_text(offline_html(svg, ballots, questions), encoding='utf-8')
    # Text forwarding copy: preserve wording while removing repository-only link destinations.
    plain_ballot = re.sub(r'\[([^\]]+)\]\([^)]+\)', r'\1', ballot_source)
    plain_ballot = plain_ballot.replace('```text\n', '').replace('```\n', '').replace('**', '')
    plain_ballot = re.sub(r'^#+ ', '', plain_ballot, flags=re.M)
    (out / 'ballot-round-1.txt').write_text(plain_ballot, encoding='utf-8')
    print('Exported PNG/SVG diagram, offline HTML and text ballot: 8 ballot questions, 40 open questions, no collected votes.')

if __name__ == '__main__': main()
