"""Generate the static site pages using shared navigation and footer. No dependencies."""
from pathlib import Path
import re
root=Path(__file__).resolve().parents[1]/'dist'
navs=[('index.html','首页'),('features.html','产品功能'),('scenarios.html','照护场景'),('guide.html','使用指南'),('about.html','关于爪伴')]
def header(active):
 links=''.join(f'<a href="{path}"'+(' aria-current="page"' if active==path else '')+f'>{label}</a>' for path,label in navs)
 return f'''<a class="skip" href="#main">跳至正文</a><header class="site-header"><div class="wrap nav"><a class="brand" href="index.html"><img src="assets/logo.svg" alt="爪伴爱心爪印标识"><strong>爪伴<span>PetCare</span></strong></a><button class="menu-toggle" aria-expanded="false" aria-controls="main-nav" aria-label="展开导航">☰</button><nav id="main-nav" aria-label="主导航">{links}<a class="nav-download" href="download.html" {'aria-current="page"' if active=='download.html' else ''}>下载 Android ↗</a></nav></div></header>'''
def footer():
 return '''<footer class="site-footer"><div class="wrap footer-grid"><div><a class="brand" href="index.html"><img src="assets/logo.svg" alt=""><strong>爪伴<span>PetCare</span></strong></a><p>认真照护，慢慢陪伴。<br>把爱放进每一个平凡的日子。</p></div><div><strong>认识爪伴</strong><a href="features.html">产品功能</a><a href="scenarios.html">照护场景</a><a href="about.html">品牌与理念</a></div><div><strong>开始使用</strong><a href="download.html">Android 下载</a><a href="guide.html">使用指南</a><a href="support.html">帮助与支持</a></div><div><strong>信息与说明</strong><a href="privacy.html">隐私说明</a><a href="terms.html">使用说明</a><span class="preview-pill">开发预览中</span></div></div><div class="wrap footer-bottom"><span>© 2026 爪伴 PetCare</span><span>小小的爪印，长长的陪伴。</span></div></footer>'''
def shell(file,title,body,desc):
 (root/file).write_text(f'<!doctype html><html lang="zh-CN"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><meta name="theme-color" content="#faf8f3"><meta name="description" content="{desc}"><title>{title} · 爪伴 PetCare</title><link rel="icon" type="image/svg+xml" href="assets/logo.svg"><link rel="stylesheet" href="style.css"><script src="app.js" defer></script></head><body>{header(file)}<main id="main">{body}</main>{footer()}</body></html>')
def intro(kicker,title,desc):
 return f'<section class="wrap page-intro"><p class="eyebrow">{kicker}</p><h1>{title}</h1><p>{desc}</p></section>'
def cta():
 return '<section class="wrap bottom-cta" id="download"><div><p class="eyebrow">A LITTLE MORE CARE, EVERY DAY</p><h2>从今天起，让陪伴更有条理。</h2></div><a class="button" href="download.html">查看 Android 下载 ↓</a></section>'
def mini(icon,title,text):
 return f'<article class="info-card"><span class="line-icon">{icon}</span><h3>{title}</h3><p>{text}</p></article>'
# Keep the existing landing page's verified product narrative.
old=(root.parent/'templates'/'index.html').read_text()
body=old.split('<main id="main">')[1].split('</main>')[0]
body=body.replace('Android / macOS · 开发预览阶段','Android 优先体验 · 开发预览阶段')
body=body.replace('href="#download"','href="download.html"')
start=body.index('<div class="feature-grid">');end=body.index('</section>',start)
body=body[:start]+'''<div class="feature-grid">
<article class="feature feature-large"><span class="number">01 / 日常照护</span><h3>每天的小事，<br>都有着落。</h3><p>喂食、散步、驱虫，一件件安排好。重复计划与本地提醒，让照护进度随时可查。</p><div class="feature-visual schedule"><div class="schedule-title">毛豆的一天 <small>示例</small></div><div><span class="task-icon">☀</span><strong>早餐时间<small>08:00 · 每天</small></strong><span class="done">已完成</span></div><div><span class="task-icon lavender">♧</span><strong>一起去散步<small>18:30 · 每天</small></strong><span class="pending">待照护</span></div></div><a class="card-link" href="features.html#care">了解日常照护 <span>↗</span></a></article>
<article class="feature health"><span class="number">02 / 健康档案</span><h3>成长的每一步，<br>都值得记下来。</h3><p>整理体重、疫苗和就诊记录。需要时导出健康档案，让下一次照护交接更从容。</p><div class="feature-visual health-preview"><div class="schedule-title">成长记录 <small>示例</small></div><div class="weight"><strong>5.2 <small>kg</small></strong><span>最近一次体重</span></div><svg viewBox="0 0 280 56" role="img" aria-label="体重记录示意曲线"><path d="M2 46H278M2 24H278" stroke="#e5dece"/><path d="M4 42 55 32 108 36 161 19 218 24 274 11" fill="none" stroke="#a48a60" stroke-width="3" stroke-linecap="round"/><circle cx="274" cy="11" r="4" fill="#a48a60"/></svg></div><a class="card-link" href="features.html#health">了解健康档案 <span>↗</span></a></article>
<article class="feature memory"><span class="number">03 / 陪伴回忆</span><h3>平凡的一天，<br>也是珍贵的一页。</h3><p>留下照片与心情，把相伴的日子收进回忆录。那些可爱的小瞬间，随时都能翻看。</p><div class="feature-visual memory-preview"><img src="assets/cat.jpg" alt="陪伴日常中的猫咪" loading="lazy"><span>今天的阳光，和你一样好。 <small>回忆示例</small></span></div><a class="card-link" href="features.html#memories">了解陪伴回忆 <span>↗</span></a></article></div>'''+body[end:]
start=body.index('<section class="section wrap download"');end=body.index('<section class="faq',start)
body=body[:start]+'''<section class="section wrap"><div class="section-heading"><div><p class="eyebrow">FOR EVERY KIND OF FAMILY</p><h2>不同的日常，一样的用心。</h2></div><a class="text-link" href="scenarios.html">探索照护场景 ↗</a></div><div class="scene-teasers"><a href="scenarios.html#new"><span>01 / 初次养宠</span><h3>把手忙脚乱，<br>变成心中有数。</h3><p>从建立第一份档案开始。</p><b>↗</b></a><a href="scenarios.html#family"><span>02 / 全家一起</span><h3>爱有很多份，<br>照护有好分工。</h3><p>让每一位家人都能参与。</p><b>↗</b></a><a href="scenarios.html#health"><span>03 / 就诊交接</span><h3>需要的时候，<br>记录就在手边。</h3><p>把重要的信息整理好。</p><b>↗</b></a></div></section>'''+cta()+body[end:]
shell('index.html','把爱，放进每一天',body,'爪伴，让宠物日常照护、健康记录与家庭分工井井有条。')
features=intro('THOUGHTFUL BY DESIGN','每一份照顾，<br>都有清晰的安排。','从日常计划到健康档案，让宠物的成长有迹可循，让家人的照护有据可查。')
blocks=[('care','01','日常照护','把“记得做”，变成“安排好”。','为喂食、换水、散步和驱虫建立照护事项，按每天或每周重复。完成和撤销都有记录，帮助家人了解最新进度。',['重复计划与本地通知','为事项指定照护人','查看完成与撤销历史'],'☀','今日照护','早餐 · 已完成','散步 · 18:30'),('health','02','健康档案','关于健康的重要小事，集中记录。','将疫苗、驱虫、用药、过敏、体重与就诊信息分类保存。按日期整理健康时间线，按需导出 PDF 或 CSV。',['六类健康记录与照片附件','查看历史记录与体重信息','为就诊、寄养准备资料'],'♡','健康档案','疫苗记录 · 已归档','体重记录 · 5.2 kg'),('family','03','家庭协作','同一个小家，共同参与。','通过邀请加入家庭，按角色与权限分工。查看照护记录与家庭周报，了解每只宠物的照护情况。',['共享宠物资料与照护事项','家庭角色和照护负责人','家庭周报与多宠汇总'],'⌂','家庭照护','早餐 · 我已完成','晚间散步 · 家人负责'),('memories','04','陪伴回忆','把平凡的瞬间，留给以后的你。','为宠物留下照片和文字，把那些值得记住的片刻放进回忆录。日子慢慢走，回忆慢慢攒。',['宠物专属回忆','照片与文字记录','随时回看陪伴瞬间'],'✳','小小回忆录','第一次一起去公园','今天也被你治愈了')]
for id,n,label,title,text,items,icon,card,a,b in blocks:
 features+=f'<section class="wrap detail-section" id="{id}"><div><p class="eyebrow">{n} / {label}</p><h2>{title}</h2><p>{text}</p><ul class="check-list">'+''.join(f'<li>{i}</li>' for i in items)+f'</ul></div><div class="product-panel panel-{id}"><span class="panel-symbol">{icon}</span><div class="panel-sheet"><div class="board-label">{card}<span>功能示意</span></div><div class="panel-row"><i>✓</i>{a}</div><div class="panel-row"><i>·</i>{b}</div></div></div></section>'
shell('features.html','产品功能',features+cta(),'了解爪伴的日常照护、健康档案、家庭协作与陪伴回忆功能。')
scenes=intro('LIFE WITH LITTLE PAWS','融入你的日常，<br>陪伴它的一生。','不必一下子做到完美。从一份清晰的安排开始，让每一天都多一点安心。')
for id,n,title,desc,steps in [('new','01','第一次养宠，也能慢慢上手。','刚刚迎接新的家庭成员，先把基础信息与每日照护建立起来。',['建立宠物档案，记录名字、生日等信息。','添加每日喂食与散步计划，设置适合的提醒时间。','完成后留下记录，逐渐找到你们的生活节奏。']),('family','02','一个家庭，多一份默契。','谁喂过、谁遛过，不必只靠记忆。把安排和进度共享给家人。',['邀请家人使用自己的账号加入家庭。','为照护事项指定负责人，明确分工。','打开应用查看同步记录，交接时再确认实际情况。']),('health','03','就诊之前，把资料准备好。','重要记录不用临时翻找，提前整理，沟通时更从容。',['平时记录疫苗、驱虫、用药与就诊信息。','选择需要的日期范围，查看健康时间线。','导出 PDF 或 CSV，并补充当前症状与实际医嘱。'])]:
 scenes+=f'<section class="wrap scenario-section" id="{id}"><div class="scenario-number">{n}</div><div><p class="eyebrow">A DAY WITH PETCARE</p><h2>{title}</h2><p>{desc}</p></div><ol class="steps">'+''.join(f'<li><span>{i+1:02d}</span>{s}</li>' for i,s in enumerate(steps))+'</ol></section>'
shell('scenarios.html','照护场景',scenes+cta(),'从初次养宠、家庭分工到就诊交接，探索爪伴的使用场景。')
guide=intro('A SIMPLE START','从第一次打开，<br>到每一天相伴。','用这份小指南，认识爪伴的基本使用流程。安装包发布后，你就可以开始。')
guide+='<section class="wrap guide-grid">'
for icon,title,text in [('01','注册自己的账号','使用邮箱注册并登录。家人各自使用自己的账号，通过家庭邀请共同照护。'),('02','建立宠物档案','添加宠物基本信息和照片。多宠家庭可以为每只宠物分别建立档案。'),('03','安排第一件照护事项','选择照护内容、时间与重复频率，根据设备提示开启通知权限。'),('04','邀请家人一起参与','由具有邀请权限的成员生成邀请，邀请家人加入并分配照护事项。'),('05','积累健康与回忆记录','按实际情况记录健康信息，为值得纪念的瞬间添加照片与文字。'),('06','需要时整理与导出','就诊或寄养前，选择日期范围导出健康记录，并核对信息是否完整。')]:guide+=mini(icon,title,text)
guide+='</section><section class="wrap guide-note"><h3>使用中的几个小提醒</h3><p>通知需要设备授权，送达可能受系统设置影响。家庭记录在应用前台同步。健康档案用于整理信息，不替代专业诊疗。</p><a class="text-link" href="support.html">查看更多常见问题 ↗</a></section>'
shell('guide.html','使用指南',guide+cta(),'了解爪伴从注册、建档到安排照护和导出记录的使用流程。')
download=intro('YOUR NEXT CHAPTER','把爪伴，<br>带进你的日常。','第一阶段优先提供 Android APK。正式安装包准备好后，将在这里开放下载。')+'''<section class="wrap download-layout"><article class="android-feature"><img src="assets/logo.svg" alt="爪伴图标"><span class="preview-pill">ANDROID</span><h2>爪伴 Android 版</h2><p>日常照护、健康档案和家庭协作，随身带着走。</p><div class="release-meta" id="android-meta">APK 安装包 · 尚未发布</div><a class="button release-button" id="android-download" aria-disabled="true">安装包准备中</a><p class="fine" id="release-status" role="status">目前为开发预览阶段，暂无公开安装包。</p></article><aside class="download-side"><h3>下载与安装</h3><ol class="steps"><li><span>01</span>发布后，从本页获取 APK 安装文件。</li><li><span>02</span>核对版本、系统要求与文件校验值。</li><li><span>03</span>在 Android 设备上打开安装包，按系统提示完成安装。</li></ol><div class="platform-later"><strong>macOS</strong><span>后续计划</span><p>当前优先完善 Android，桌面版暂不提供下载。</p></div><a class="text-link" href="guide.html">先看看使用指南 ↗</a></aside></section><section class="wrap release-note"><p class="eyebrow">RELEASE NOTES</p><h2>版本动态</h2><div><span class="preview-pill">开发预览</span><p>公开版本尚未发布。正式发布时，将一并提供版本号、更新说明、系统要求与文件校验值。</p></div></section>'''
shell('download.html','Android 下载',download,'查看爪伴 Android APK 下载状态、安装说明与版本动态。')
about=intro('SMALL PAWS, LASTING COMPANY','认真照护，<br>慢慢陪伴。','爪伴的出发点很简单：让爱它的人，更容易把照护这件事做好。')+'''<section class="wrap about-story"><div class="brand-art"><img src="assets/logo.svg" alt="爪伴标识：爪印、爱心与完成勾号"><span>PAWS + LOVE + CARE</span></div><div><p class="eyebrow">THE MEANING BEHIND OUR MARK</p><h2>一个爪印，<br>一份放在心上的牵挂。</h2><p>爪印代表毛孩子，爱心代表陪伴，中间的小勾代表每一次认真完成的照护。我们希望，每一份关心都能变成日常里可见的小行动。</p><p>从记住一顿饭，到整理一份健康档案，再到家人之间的一次交接，爪伴让这些平凡的小事更有条理。</p></div></section><section class="wrap guide-grid">'''+mini('01','从日常出发','围绕照护、健康与家庭协作设计功能，让记录服务于真实生活。')+mini('02','让家人一起参与','把信息与分工说明白，让每一份陪伴都能衔接起来。')+mini('03','尊重每一段成长','用资料和回忆记录变化，留下你们共同走过的日子。')+'''</section><section class="wrap guide-note"><h3>我们仍在认真打磨</h3><p>爪伴目前处于开发预览阶段，尚未公开发行。正式运营主体与支持联系方式将在公开发布前补充。</p><a class="text-link" href="support.html">关于帮助与支持 ↗</a></section>'''
shell('about.html','关于爪伴',about+cta(),'认识爪伴的品牌理念：认真照护，慢慢陪伴。')
# Retain the factual preview notices in the information pages, using the same site chrome.
for name in ['privacy','terms','support']:
 old=(root.parent/'templates'/f'{name}.html').read_text()
 content=old.split('<main')[1].split('>',1)[1].split('</main>')[0]
 title=re.search(r'<h1>(.*?)</h1>',content).group(1)
 if name=='support':
  content+='''<h2>常见问题</h2><details><summary>为什么现在还不能下载？</summary><p>目前尚未发布公开安装包。正式开放时，Android 下载页会显示版本信息和下载入口。</p></details><details><summary>家人需要共用一个账号吗？</summary><p>不需要。每位家人使用自己的账号，通过邀请加入同一家庭，并按成员权限参与照护。</p></details><details><summary>提醒没有出现怎么办？</summary><p>先检查设备是否允许应用通知，再检查计划时间与系统通知设置。提醒送达可能受设备系统限制影响。</p></details><details><summary>就诊时能带上记录吗？</summary><p>可以按日期范围导出健康记录为 PDF 或 CSV，并根据实际情况补充最新信息。</p></details>'''
 content=content.replace('href="./#download"', 'href="download.html"')
 shell(f'{name}.html',title,'<section class="document wrap">'+content+'</section>',title+'与开发预览信息。')
