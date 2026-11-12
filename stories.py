"""Story scripts. Markup in text: *red emphasis*, _yellow emphasis_."""
from engine import A, B, Pr

HOOK_G = '*НЕ* БУДЬ КАК *ГОША*'
CHATBG = dict(bg='grad', bgp=dict(c1='#4c4585', c2='#1b1930', cy=600))
YELLOW = dict(bg='grad', bgp=dict(c1='#fff3b0', c2='#d9b64a'))
STEEL = dict(bg='grad', bgp=dict(c1='#e3e9f2', c2='#8793a8'))
TAGS = '#небудькакгоша #гоша #анимация #мультик #истории #юмор #рек'


def lift():
    r1 = (1, 'Не нажимай кнопку, которой вчера не было')
    r2 = (2, 'Если лифт застрял — не говори «хуже не будет»')
    r3 = (3, 'Если в темноте кто-то дышит — не начинай разговор')
    r4 = (4, 'Не выходи на этаже, которого нет')
    return dict(
        id='RU6_Gosha_v_Lifte', title='Не будь как Гоша: в лифте', mood='comedy',
        hook=['4 ПРАВИЛА', 'ЕСЛИ ТЫ В ЛИФТЕ', HOOK_G],
        caption='В доме 9 этажей. А кнопок в лифте — 10 😳 Гоша, конечно, нажал. Досмотри до конца и посчитай кнопки ещё раз 👀\n\n'
                + TAGS + ' #лифт #страшилки',
        scenes=[
            dict(bg='elevator', bgp=dict(floor='1'), actors=dict(g=A('gosha', expr='happy', pose='wave')), beats=[
                B('N', 'Это Гоша. Гоша зашёл в лифт. И сейчас нарушит все правила.', hook=True, fx='zoom')]),
            dict(rule=r1, props=dict(pn=Pr('panel', 540, 1270, n=9, base=9, s=0.95)), **STEEL, beats=[
                B('N', 'В доме _девять_ этажей.'),
                B('N', 'А кнопок сегодня — *десять*.', pn=dict(n=10), sfx='sting', fx=['zoom', 'red'])]),
            dict(rule=r1, bg='elevator', bgp=dict(floor='1', n=10, hot=1),
                 actors=dict(g=A('gosha', 480, expr='happy', pose='point')), beats=[
                B('G', 'О, новая кнопка!'),
                B('N', 'Гоша, конечно, нажал.', g=dict(expr='smug', x=620), sfx='click@0.3')]),
            dict(rule=r2, bg='elevator', bgp=dict(floor='?', n=10, hot=1), actors=dict(g=A('gosha', expr='shock', pose='spread')), beats=[
                B('N', 'Лифт встал между этажами.', fx='shake', sfx='boom'),
                B('G', 'Ну, хуже уже не будет.', g=dict(expr='smug', pose='hips')),
                B('N', 'Свет погас. Спасибо, Гоша.', dark=1, big='ЩЁЛК', sfx='click', g=dict(expr='scared', pose='idle'))]),
            dict(rule=r3, bg='elevator', dark=1, mood='spooky',
                 actors=dict(g=A('gosha', 320, expr='scared'), k=A('courier', 780, show=False, expr='bored')), beats=[
                B('N', 'В темноте кто-то задышал.', k=dict(show=True), sfx='riser'),
                B('G', 'Вам какой этаж?', g=dict(expr='happy', look=(1, 0))),
                B('U', 'Мне... *десятый*.', g=dict(expr='shock'), k=dict(expr='shock'), sfx='sting', fx='red')]),
            dict(rule=r4, bg='hall', bgp=dict(sign='10 ЭТАЖ'),
                 actors=dict(g=A('gosha', 300, expr='shock'),
                             b=A('baba', 780, show=False, flip=True, expr='joy', hold=('plate', 'БЛИНЫ', '#e0a030'))), beats=[
                B('N', 'Двери открылись. Десятый этаж.', sfx='ding', fx='flash'),
                B('N', 'Там стояла _бабушка_. С блинами.', b=dict(show=True), sfx='pop'),
                B('B', 'Гошенька! А я переехала повыше!', g=dict(expr='happy', pose='up'))]),
            dict(rule=r4, bg='elevator', bgp=dict(floor='10', n=10),
                 actors=dict(k=A('courier', expr='bored', hold=('box', 'ЗАКАЗ', '#c9a36b'))), beats=[
                B('N', 'Дышал, кстати, курьер. Он застрял ещё во вторник.', sfx='fail')]),
            dict(rule=r4, props=dict(pn=Pr('panel', 540, 1300, n=10, base=9, s=0.85)), **STEEL, beats=[
                B('N', 'Не будь как Гоша.'),
                B('N', 'И... почему кнопок уже *одиннадцать*?', pn=dict(n=11), sfx='sting', fx=['zoom', 'red'])]),
        ])


def kontrolnaya():
    r1 = (1, 'Никогда не говори «я всё выучил»')
    r2 = (2, 'Не списывай у того, кто улыбается')
    r3 = (3, 'Если за спиной стало тихо — не оборачивайся')
    r4 = (4, 'Не спорь с оценкой')
    return dict(
        id='RU7_Gosha_na_Kontrolnoy', title='Не будь как Гоша: на контрольной', mood='comedy',
        hook=['4 ПРАВИЛА', 'НА КОНТРОЛЬНОЙ', HOOK_G],
        caption='Гоша списал у соседа всё. Даже фамилию 💀 А в конце выяснилось кое-что странное про этого соседа...\n\n'
                + TAGS + ' #школа #контрольная',
        scenes=[
            dict(bg='klass', actors=dict(g=A('gosha', expr='happy', pose='up')), beats=[
                B('N', 'Это Гоша. У Гоши контрольная. И Гоша нарушит все правила.', hook=True, fx='zoom')]),
            dict(rule=r1, bg='klass', actors=dict(g=A('gosha', 310, expr='smile'),
                                                  t=A('teacher', 780, expr='neutral', pose='hips')), beats=[
                B('T', 'Кто готов к контрольной?'),
                B('G', 'Я всё выучил!', g=dict(expr='happy', pose='up'), sfx='pop'),
                B('N', 'Гоша выучил. Но *географию*.', g=dict(expr='smug', pose='hips')),
                B('N', 'А контрольная — по _математике_.', g=dict(expr='shock', pose='cover'), t=dict(expr='smug'),
                  sfx='fail', fx='zoom')]),
            dict(rule=r2, bg='klass', bgp=dict(board='ВАРИАНТ 1'),
                 actors=dict(g=A('gosha', 310, expr='scared'), v=A('vova', 780, expr='smug', pose='think')),
                 props=dict(n=Pr('note', 540, 1280, text='Фамилия:|Сидоров Вова', show=False, rot=-4)), beats=[
                B('N', 'Сосед Вова писал уверенно. И улыбался.', v=dict(expr='wink')),
                B('N', 'Гоша списал всё.', g=dict(expr='smug', look=(1, 0.4))),
                B('N', 'Даже *фамилию*.', n=dict(show=True), g=dict(expr='happy'), sfx='fail', fx='zoom')]),
            dict(rule=r3, bg='klass', mood='spooky',
                 actors=dict(t=A('teacher', 700, show=False, expr='angry', pose='hips', s=1.75, y=1500),
                             g=A('gosha', 380, expr='scared', s=1.55)), beats=[
                B('N', 'За спиной стало тихо. *Слишком* тихо.', dark=0.35),
                B('G', 'Вов, а седьмой какой?', g=dict(expr='smug', look=(1, 0))),
                B('T', 'Седьмой — «Б», Гоша.', t=dict(show=True), g=dict(expr='shock'), sfx='sting', fx=['red', 'shake'],
                  dark=0)]),
            dict(rule=r4, bg='klass', actors=dict(g=A('gosha', 310, expr='angry', pose='up'),
                                                  t=A('teacher', 780, expr='bored', flip=True)),
                 props=dict(n=Pr('sign', 540, 1100, text='2', size=200, show=False)), beats=[
                B('G', 'А почему *два*?!', n=dict(show=True), sfx='boom'),
                B('T', 'Потому что это _две_ работы Вовы Сидорова.', n=dict(show=False), g=dict(expr='shock', pose='idle'),
                  t=dict(hold=('box', 'ВОВА x2', '#fff8d6')))]),
            dict(rule=r4, actors=dict(v=A('vova', expr='joy', pose='up')), **YELLOW, beats=[
                B('N', 'Вова, кстати, получил пять. За обе.', sfx='ding')]),
            dict(rule=r4, bg='klass', mood='spooky', dark=0.3,
                 actors=dict(g=A('gosha', 310, expr='neutral'), v=A('vova', 780, expr='smile')), beats=[
                B('N', 'Самое странное: Вовы в журнале *нет*.', sfx='riser', g=dict(expr='scared')),
                B('N', 'Не будь как Гоша.'),
                B('N', 'И... кто тогда сидит рядом?', v=dict(expr='grin', look=(-1, 0)), g=dict(look=(1, 0)), dark=0.5,
                  sfx='sting', fx=['red', 'zoom'])]),
        ])


def holodilnik():
    r1 = (1, 'Не открывай холодильник после полуночи')
    r2 = (2, 'Не бери последнюю котлету')
    r3 = (3, 'Если свет включился сам — не жуй')
    r4 = (4, 'Никогда не сваливай на кота')
    K = dict(bg='kitchen')
    return dict(
        id='RU8_Gosha_i_Holodilnik', title='Не будь как Гоша: ночью у холодильника', mood='comedy',
        hook=['4 ПРАВИЛА', 'ЕСЛИ НОЧЬЮ ЗАХОТЕЛ ЕСТЬ', HOOK_G],
        caption='3 часа ночи. Холодильник. Последняя котлета с запиской «Не трогать. Папа» 🥶 Угадай, что сделал Гоша.\n\n'
                + TAGS + ' #холодильник #ночнойдожор',
        scenes=[
            dict(bgp=dict(night=1), dark=0.4, actors=dict(g=A('gosha', 180, expr='smug', pose='think')), **K, beats=[
                B('N', 'Это Гоша. Три часа ночи. Гоша идёт к холодильнику.', hook=True, g=dict(x=450), d=3.9)]),
            dict(rule=r1, bgp=dict(night=1), dark=0.4, actors=dict(g=A('gosha', 420, expr='smug')), **K, beats=[
                B('N', 'После полуночи холодильник уже _не твой_.'),
                B('G', 'Я только посмотреть.', g=dict(expr='wink', pose='point')),
                B('N', 'Никто. Никогда. Не «только смотрит».', bgp=dict(open=1), dark=0.15,
                  g=dict(expr='joy', pose='up'), sfx='pop', fx='flash')]),
            dict(rule=r2, props=dict(pl=Pr('plate', 540, 1500, label='КОТЛЕТА', s=1.7),
                                     n=Pr('note', 540, 1060, text='НЕ ТРОГАТЬ!|Папа.', show=False, rot=5)), **YELLOW, beats=[
                B('N', 'Там лежала одна котлета.', sfx='ding'),
                B('N', 'И записка: «Не трогать. *Папа*».', n=dict(show=True), sfx='pop', fx='zoom')]),
            dict(rule=r2, bgp=dict(night=1, open=1), dark=0.15,
                 actors=dict(g=A('gosha', 420, expr='happy', hold=('plate', 'КОТЛЕТА', '#8a4a2a'))), **K, beats=[
                B('N', 'Гоша тронул.', sfx='fail')]),
            dict(rule=r3, bgp=dict(night=1, open=1), dark=0.4, mood='spooky',
                 actors=dict(p=A('dad', 760, show=False, expr='angry', pose='hips', s=1.75, y=1520),
                             g=A('gosha', 400, expr='joy', hold=('plate', 'КОТЛЕТА', '#8a4a2a'))), **K, beats=[
                B('N', 'Свет включился. Сам.', dark=0, big='ЩЁЛК', sfx='click', fx='flash', g=dict(expr='shock'), d=1.5),
                B('N', 'Гоша замер. С котлетой во рту.', g=dict(expr='scared')),
                B('N', 'За спиной стоял *папа*.', p=dict(show=True), sfx='sting', fx=['red', 'shake'])]),
            dict(rule=r4, bgp=dict(night=1), actors=dict(g=A('gosha', 300, expr='scared'),
                                                         p=A('dad', 780, expr='angry', pose='hips'),
                                                         c=A('cat', 540, show=False, s=1.5, expr='smug')), **K, beats=[
                B('P', 'Кто съел мою котлету?'),
                B('G', 'Это кот!', g=dict(expr='happy', pose='point'), sfx='pop'),
                B('P', 'Гоша. У нас *нет* кота.', p=dict(expr='bored', pose='idle'), g=dict(expr='neutral', pose='idle')),
                B('C', 'Мяу.', c=dict(show=True), g=dict(expr='shock', look=(1, 1)), p=dict(expr='shock', look=(-1, 1)),
                  sfx='meow', fx='zoom', d=1.5),
                B('N', 'Кот был. Просто раньше он молчал.', sfx='fail')]),
            dict(rule=r4, bgp=dict(night=1, open=1), dark=0.3,
                 actors=dict(c=A('cat', 480, s=2.2, expr='smug', hold=('plate', 'БОРЩ', '#c0392b'))), **K, beats=[
                B('N', 'Не будь как Гоша.'),
                B('N', 'И... кто тогда доел *борщ*?', sfx='sting', fx=['zoom', 'red'])]),
        ])


def magazin():
    r1 = (1, 'Не верь словам «мы на пять минут»')
    r2 = (2, 'Ничего не клади в тележку сам')
    r3 = (3, 'Если мама встретила подругу — не говори «пойдём»')
    r4 = (4, 'Никогда не стой в очереди один')
    S = dict(bg='shop')
    food = [('МОЛОКО', '#5aa9e6'), ('СЫР', '#f2c94c'), ('ГРЕЧКА', '#b57c3e'), ('ЧАЙ', '#6cc46a'),
            ('ПОРОШОК', '#b57edc'), ('ТАЗИК', '#e2574c')]
    return dict(
        id='RU9_Gosha_v_Magazine', title='Не будь как Гоша: с мамой в магазине', mood='comedy',
        hook=['4 ПРАВИЛА', 'В МАГАЗИНЕ С МАМОЙ', HOOK_G],
        caption='«Мы на 5 минут, только за хлебом» 🛒 Отметь того, кто тоже стоял один на кассе, пока мама «сейчас вернётся» 😭\n\n'
                + TAGS + ' #мама #магазин #жиза',
        scenes=[
            dict(actors=dict(m=A('mom', 330, expr='happy', pose='point'), g=A('gosha', 760, expr='bored')), **S, beats=[
                B('N', 'Это Гоша. Гоша пошёл с мамой в магазин. Это надолго.', hook=True, fx='zoom')]),
            dict(rule=r1, actors=dict(m=A('mom', 260, expr='happy', pose='wave', s=1.35), g=A('gosha', 840, expr='smile', s=1.35)),
                 props=dict(c=Pr('cart', 550, 1590, items=[], s=1.05)), **S, beats=[
                B('M', 'Мы на пять минут. Только за хлебом.'),
                B('N', 'Прошёл _час_.', c=dict(items=food), g=dict(expr='bored'), m=dict(expr='joy', pose='idle'),
                  sfx='whoosh', fx='zoom'),
                B('N', 'Хлеба в тележке всё ещё *нет*.', sfx='fail', g=dict(expr='sad'))]),
            dict(rule=r2, actors=dict(m=A('mom', 280, expr='neutral', look=(-1, 0), s=1.35),
                                      g=A('gosha', 840, expr='smug', s=1.35, flip=True, hold=('box', 'ЧИПСЫ', '#f2c94c'))),
                 props=dict(c=Pr('cart', 560, 1590, items=food, s=1.05)), **S, beats=[
                B('N', 'Гоша тихо положил чипсы.', g=dict(x=760)),
                B('M', 'Гоша. Положи. Где. Взял.', m=dict(expr='angry'), g=dict(expr='shock'), sfx='boom', fx='shake'),
                B('N', 'Мама даже не обернулась.', g=dict(expr='scared'), sfx='fail')]),
            dict(rule=r3, actors=dict(m=A('mom', 250, expr='joy', pose='up', s=1.3), a=A('aunt', 560, expr='joy', pose='up', s=1.3),
                                      g=A('gosha', 880, expr='scared', s=1.3)), **S, beats=[
                B('N', 'Мама встретила тётю Люду.', sfx='sting', fx='red'),
                B('G', 'Мам, пойдём?', g=dict(expr='sad'), m=dict(pose='spread'), a=dict(pose='wave')),
                B('N', 'Это было в *марте*.', g=dict(expr='bored'), m=dict(pose='wave'), a=dict(pose='spread')),
                B('N', 'Они говорят до сих пор.', g=dict(over=dict(beard=1), expr='bored'), sfx='fail', fx='zoom',
                  m=dict(pose='up'), a=dict(pose='up'))]),
            dict(rule=r4, actors=dict(g=A('gosha', 330, expr='neutral'), m=A('mom', 780, expr='smile', pose='point'),
                                      s=A('cashier', 780, show=False, expr='bored')), **S, beats=[
                B('M', 'Постой в очереди. Я за сметаной.'),
                B('N', 'Мама ушла. Очередь — *подошла*.', m=dict(x=1400), s=dict(show=True), g=dict(expr='scared'),
                  sfx='sting', fx='red'),
                B('S', 'С вас четыре тысячи.', s=dict(pose='point'), g=dict(expr='cry'), sfx='boom')]),
            dict(rule=r4, actors=dict(g=A('gosha', 200, expr='bored', s=1.3), m=A('mom', 820, expr='joy', s=1.3)),
                 props=dict(c=Pr('cart', 500, 1600, items=food + [('ЕЩЁ ТАЗИК', '#e2574c'), ('СМЕТАНА', '#5aa9e6')], s=1.0)),
                 **S, beats=[
                B('N', 'Мама вернулась. Со второй тележкой.', sfx='pop'),
                B('N', 'Не будь как Гоша.'),
                B('N', 'И... хлеб они так и *не купили*.', g=dict(expr='cry'), sfx='fail', fx='zoom')]),
        ])


def chat_klassa():
    r1 = (1, 'Не пиши в чат класса после полуночи')
    r2 = (2, 'Не отправляй голосовое, не послушав')
    r3 = (3, 'Никогда не путай чаты')
    r4 = (4, 'Не удаляй — скриншот уже сделан')
    ch = dict(title='Наш 7 «Б»', sub='31 участник', letter='7', col='#f2672e')
    NR = dict(bg='night_room', bgp=dict(clock='1:07'), dark=0.25)
    return dict(
        id='RU10_Gosha_i_Chat_Klassa', title='Не будь как Гоша: в чате класса', mood='comedy',
        hook=['4 ПРАВИЛА', 'В ЧАТЕ КЛАССА', HOOK_G],
        caption='Гоша перепутал чаты. И написал про учительницу. В чат, где сидит учительница 💀 Скинь это тому, кто тоже так делал.\n\n'
                + TAGS + ' #школа #чаткласса #жиза',
        scenes=[
            dict(actors=dict(g=A('gosha', expr='happy', hold='phone')), **NR, beats=[
                B('N', 'Это Гоша. У Гоши есть телефон. И чат класса. Зря.', hook=True, fx='zoom')]),
            dict(rule=r1, chat=ch, **CHATBG, beats=[
                B('N', 'В час ночи Гоша написал:', msg=('in', 'Всем спокойной ночи', 'Катя')),
                B('G', '«Кто сделал домашку?»', msg=('out', 'Кто сделал домашку???')),
                B('N', 'В чате тридцать человек. Ответил *один*.', typing='Марья Ивановна печатает...'),
                B('T', '«Я сделала, Гоша. Спи».', msg=('in', 'Я сделала, Гоша. Спи.', 'Марья Ивановна'), sfx='sting',
                  fx='red')]),
            dict(rule=r2, chat=ch, **CHATBG, beats=[
                B('N', 'Гоша отправил голосовое.', msg=('voice',)),
                B('N', 'На фоне кричала мама:'),
                B('M', '«Гоша, ты трусы поменял?!»', big='ТРУСЫ|ПОМЕНЯЛ?!', bigcol='#ffb066', sfx='boom', fx='shake'),
                B('N', 'Класс спрашивает до сих пор.', sfx='fail',
                  msg=[('in', 'АХАХАХАХА', 'Вова'), ('in', 'Так поменял или нет?', 'Катя'), ('in', 'Гоша, ответь классу', 'Дима')])]),
            dict(rule=r3, chat=ch, **CHATBG, beats=[
                B('N', 'Гоша хотел написать Вове:'),
                B('G', '«Марья Ивановна злая, как монстр».', msg=('out', 'Марья Ивановна сегодня злая, как монстр из шкафа')),
                B('N', 'Но это был *не тот* чат.', sfx='fail', fx='zoom'),
                B('N', 'Марья Ивановна печатает...', typing='Марья Ивановна печатает...', sfx='riser', fx='red')]),
            dict(rule=r4, chat=ch, **CHATBG, beats=[
                B('N', 'Гоша удалил сообщение.', delmsg=7, sfx='click'),
                B('V', '«Скрин есть».', msg=('in', 'Скрин есть.', 'Вова'), sfx='boom'),
                B('N', 'Скрин есть даже у *директора*.', msg=[('in', 'И у меня', 'Катя'), ('in', 'Переслал в чат школы', 'Дима')],
                  sfx='fail')]),
            dict(rule=r4, actors=dict(g=A('gosha', expr='cry', hold='phone')), **NR, beats=[
                B('N', 'Не будь как Гоша.')]),
            dict(rule=r4, chat=ch, **CHATBG, beats=[
                B('N', 'И... «Директор добавил вас в чат».', msg=('sys', 'Директор добавил вас в чат «Гоша, зайди»'),
                  sfx='sting', fx=['red', 'zoom'], d=3.0)]),
        ])


def plackart():
    r1 = (1, 'Никогда не говори «я не голодный»')
    r2 = (2, 'Не смотри на верхнюю полку')
    r3 = (3, 'Не пей чай перед сном')
    r4 = (4, 'Не спи перед своей станцией')
    T = dict(bg='train')
    eda = [('КУРИЦА', '#c98f4e'), ('ЯЙЦА', '#e8dcc6'), ('ОГУРЦЫ', '#6cc46a')]
    return dict(
        id='RU11_Gosha_v_Plackarte', title='Не будь как Гоша: в плацкарте', mood='comedy',
        hook=['4 ПРАВИЛА', 'В ПЛАЦКАРТЕ', HOOK_G],
        caption='Гоша ехал в Тулу. Проснулся во Владивостоке 🚂 А ноги с верхней полки ему ещё и помахали... Кто ездил в плацкарте — поймёт.\n\n'
                + TAGS + ' #поезд #плацкарт #жиза',
        scenes=[
            dict(actors=dict(g=A('gosha', expr='happy', pose='wave')), **T, beats=[
                B('N', 'Это Гоша. Гоша едет в поезде. Сутки. В плацкарте.', hook=True, fx='zoom')]),
            dict(rule=r1, actors=dict(g=A('gosha', 300, expr='smile'), a=A('aunt', 790, expr='happy', pose='point')),
                 props=dict(st=Pr('stack', 545, 1650, items=eda, show=False, s=0.9)), **T, beats=[
                B('A', 'Мальчик, ты кушать будешь?'),
                B('G', 'Спасибо, я не голодный.', g=dict(pose='wave'), a=dict(expr='shock', pose='idle')),
                B('N', 'Тётя Валя достала курицу. Яйца. Огурцы.', st=dict(show=True), a=dict(expr='joy'), g=dict(expr='neutral', pose='idle'),
                  sfx='pop'),
                B('N', 'И *вторую* курицу.', st=dict(items=eda + [('КУРИЦА №2', '#c98f4e'), ('ПИРОЖКИ', '#e0a030')]),
                  g=dict(expr='shock'), sfx='fail', fx='zoom')]),
            dict(rule=r2, actors=dict(g=A('gosha', 420, expr='neutral')),
                 props=dict(f=Pr('feet', 900, 790, s=1.0)), **T, beats=[
                B('N', 'С верхней полки торчали ноги.', g=dict(look=(1, -1))),
                B('N', 'Гоша посмотрел.', g=dict(expr='bored', look=(1, -1)), cam=(1.15, 640, 860)),
                B('N', 'Ноги ему *помахали*.', f=dict(wave=1), g=dict(expr='scared', look=(1, -1)), sfx='sting', fx=['red', 'shake'],
                  cam=(1.15, 640, 860))]),
            dict(rule=r3, actors=dict(g=A('gosha', expr='joy', hold=('box', 'ЧАЙ №3', '#c98f4e'))), **T, beats=[
                B('N', 'Гоша выпил три стакана чая.', sfx='pop')]),
            dict(rule=r3, bg='hall', dark=0.3, actors=dict(g=A('gosha', 120, expr='scared', pose='cover')),
                 props=dict(s=Pr('sign', 640, 900, text='ЗАКРЫТО|САНИТАРНАЯ ЗОНА', size=44, show=False, z=-1)), beats=[
                B('N', 'Ночью он побежал в туалет.', g=dict(x=230, shake=5)),
                B('N', 'А там — *санитарная зона*.', s=dict(show=True), g=dict(expr='cry', pose='up', shake=8), sfx='fail',
                  fx='zoom')]),
            dict(rule=r4, bgp=dict(night=1), dark=0.3, actors=dict(g=A('gosha', expr='sleep')),
                 props=dict(z=Pr('text', 760, 900, text='z z Z', size=80, col='#cfe0ff')), **T, beats=[
                B('N', 'Гоша прилёг на минутку.')]),
            dict(rule=r4, bg='grad', bgp=dict(c1='#bfe4ff', c2='#5a93c9'), actors=dict(g=A('gosha', 280, expr='shock', pose='cover')),
                 props=dict(s=Pr('sign', 730, 1120, text='ВЛАДИ-|ВОСТОК', size=84, rot=-5, tcol='#1f4fa8', z=-1)), beats=[
                B('N', 'Проснулся он во _Владивостоке_.', sfx='boom', fx=['flash', 'shake']),
                B('N', 'Ехал Гоша, кстати, в *Тулу*.', g=dict(expr='cry', pose='idle'), sfx='fail')]),
            dict(rule=r4, bgp=dict(night=1), dark=0.45, mood='spooky', actors=dict(g=A('gosha', 400, expr='scared', look=(1, -1))),
                 props=dict(f=Pr('feet', 900, 790, s=1.0)), **T, beats=[
                B('N', 'Не будь как Гоша.'),
                B('N', 'И... чьи это были *ноги*?', f=dict(wave=1), cam=(1.3, 660, 860), sfx='sting', fx='red')]),
        ])


def ya_znayu():
    ch = dict(title='Неизвестный номер', sub='+7 *** *** ** 13', letter='?', col='#5b6070')
    NR = dict(bg='night_room', dark=0.3)
    return dict(
        id='RU12_Ya_Znayu', title='Я знаю, что ты сделал', mood='spooky',
        hook=['В 3:00 МНЕ НАПИСАЛИ:', '*«Я ЗНАЮ,*', '*ЧТО ТЫ СДЕЛАЛ»*'],
        caption='В 3:00 Гоше написал неизвестный номер: «Я знаю, что ты сделал» 😨 Гоша начал признаваться. ВО ВСЁМ. А зря...\n\n'
                '#гоша #переписка #истории #страшилки #анимация #мультик #юмор #рек',
        scenes=[
            dict(actors=dict(g=A('gosha', expr='scared', hold='phone')), **NR, beats=[
                B('N', 'В три ночи Гоше написали. С незнакомого номера.', hook=True, fx=['zoom', 'red'], sfx='msg')]),
            dict(chat=ch, **CHATBG, beats=[
                B('Q', '«Я знаю, что ты сделал».', msg=('in', 'Я знаю, что ты сделал.'), sfx='sting', d=2.2)]),
            dict(actors=dict(g=A('gosha', expr='scared', hold='phone')), cam=(1.3, 540, 860), **NR, beats=[
                B('N', 'Гоша вспотел. Он сделал _много чего_.', g=dict(shake=4))]),
            dict(chat=ch, **CHATBG, beats=[
                B('G', '«Это про вазу?»', msg=('out', 'Это про вазу?')),
                B('Q', '«Какую вазу?»', msg=('in', 'Какую вазу?'), sfx='fail'),
                B('G', '«Тогда про двойку?»', msg=('out', 'Тогда про двойку?')),
                B('Q', '«Какую *двойку*?»', msg=('in', 'Какую ДВОЙКУ?'), sfx='boom', fx='shake')]),
            dict(actors=dict(g=A('gosha', expr='cry', hold='phone')), cam=(1.3, 540, 860), **NR, beats=[
                B('N', 'Гоша решил молчать. Не смог.', g=dict(expr='scared'))]),
            dict(chat=ch, **CHATBG, beats=[
                B('G', '«Про кота и мамины шторы?!»', msg=('out', 'Про кота и мамины шторы?!')),
                B('N', 'Неизвестный печатал целую минуту.', typing='печатает...', sfx='riser'),
                B('Q', '«Я про мусор. Ты его не вынес».', msg=('in', 'Я про мусор. Ты его не вынес.')),
                B('Q', '«Это *мама*. Новый номер».', msg=('in', 'Это мама. Новый номер.'), sfx='fail', fx='zoom')]),
            dict(mood='comedy', actors=dict(g=A('gosha', expr='joy', pose='up')), bg='night_room', dark=0.15, beats=[
                B('N', 'Гоша выдохнул. Рано.', sfx='pop')]),
            dict(mood='comedy', chat=dict(ch, title='Мама', letter='М', col='#f58a3c', sub='в сети'), **CHATBG, beats=[
                B('M', '«А теперь — про вазу, двойку и шторы».',
                  msg=[('in', 'Я знаю, что ты сделал.'), ('in', 'Это мама. Новый номер.'),
                       ('in', 'А теперь — про вазу, двойку и шторы.')], sfx='sting', fx='red')]),
            dict(bg='night_room', dark=0.3, actors=dict(g=A('gosha', 300, expr='scared', hold='phone'),
                                                        m=A('mom', 790, show=False, expr='angry', pose='hips')), beats=[
                B('N', 'Мама уже стояла в дверях.', m=dict(show=True), sfx='boom', fx='shake'),
                B('N', 'И тут телефон звякнул снова.', sfx='msg', g=dict(expr='shock'), m=dict(expr='neutral'))]),
            dict(chat=dict(title='Ещё один номер', sub='+7 *** *** ** 14', letter='?', col='#5b6070'), **CHATBG, beats=[
                B('Q', '«Я тоже всё знаю. *Папа*».', msg=('in', 'Я тоже всё знаю. Папа.'), sfx='sting', fx=['red', 'zoom'], d=2.8)]),
        ])


def idi_uzhinat():
    ch = dict(title='Мама', sub='в сети', letter='М', col='#f58a3c')
    return dict(
        id='RU13_Idi_Uzhinat', title='Иди ужинать', mood='spooky',
        hook=['МАМА ЗОВЁТ УЖИНАТЬ.', 'НО МАМА ПИШЕТ:', '*«Я НЕ ДОМА»*'],
        caption='Мама зовёт с кухни ужинать. И в ту же секунду пишет: «Я в магазине, буду через час» 😳 Тогда КТО на кухне?! Финал не угадаешь.\n\n'
                '#гоша #небудькакгоша #страшилки #истории #анимация #мультик #монстр #рек',
        scenes=[
            dict(bg='room', mood='comedy', actors=dict(g=A('gosha', expr='happy', pose='up')), beats=[
                B('N', 'Гоша услышал с кухни мамин голос.', hook=True, fx='zoom')]),
            dict(bg='room', mood='comedy', actors=dict(g=A('gosha', expr='happy', pose='up')), beats=[
                B('VO', '«Гоша, иди ужинать!»'),
                B('N', 'Гоша уже пошёл. И тут звякнул телефон.', g=dict(x=700, pose='idle', hold='phone', expr='neutral'),
                  sfx='msg@0.9')]),
            dict(chat=ch, **CHATBG, beats=[
                B('M', '«Я в магазине. Буду через час».', msg=('in', 'Я в магазине. Буду через час.'), sfx='sting', fx='red')]),
            dict(bg='room', dark=0.35, actors=dict(g=A('gosha', expr='scared', hold='phone')), cam=(1.3, 540, 860), beats=[
                B('N', 'Гоша перечитал три раза.', g=dict(shake=4)),
                B('VO', '«Го-о-оша... *Остынет же!*»', big='ГО-О-ОША...', bigcol='#ff3b30', fx=['shake', 'red'], sfx='boom',
                  g=dict(expr='shock', shake=8))]),
            dict(chat=ch, **CHATBG, beats=[
                B('G', '«Мам, а кто тогда на кухне?»', msg=('out', 'Мам, а кто тогда на кухне?')),
                B('N', 'Мама печатала очень долго.', typing='печатает...', sfx='riser'),
                B('M', '«Никто. *Не ходи туда*».', msg=('in', 'Никто. НЕ ХОДИ ТУДА.'), sfx='sting', fx='red')]),
            dict(bg='hall', dark=0.4, bgp=dict(open=1), actors=dict(g=A('gosha', 150, expr='scared', pose='cover')), beats=[
                B('N', 'Гоша, конечно, пошёл.', g=dict(x=420))]),
            dict(bg='kitchen', mood='comedy', actors=dict(x=A('monster', 470, expr='bored', over=dict(apron=1),
                                                             hold=('plate', 'БОРЩ', '#c0392b'))), beats=[
                B('N', 'На кухне стоял *монстр из шкафа*. В фартуке.', sfx='sting', fx=['flash', 'zoom']),
                B('X', 'Чё? Я борщ сварил.', x=dict(expr='neutral'), sfx='fail')]),
            dict(bg='kitchen', mood='comedy', actors=dict(g=A('gosha', 300, expr='neutral'),
                                                          x=A('monster', 780, expr='smug', over=dict(apron=1))), beats=[
                B('N', 'Он просто научился готовить. И говорить маминым голосом.', x=dict(pose='hips')),
                B('N', 'Борщ, кстати, был вкуснее маминого.', g=dict(expr='joy', hold=('plate', 'БОРЩ', '#c0392b')), sfx='ding'),
                B('N', 'Маме об этом лучше не знать.', g=dict(expr='wink'), x=dict(expr='wink'))]),
            dict(bg='room', dark=0.45, cam=(1.5, 900, 950), beats=[
                B('N', 'И... кто тогда зовёт из *шкафа*?', big='ГО-О-ОША...', bigcol='#ff3b30', sfx='sting', fx=['red', 'shake'],
                  d=2.8)]),
        ])


def vam_zakaz():
    ch = dict(title='Бабушка из дома напротив', sub='в сети', letter='Б', col='#8e5aa8')
    stickers = [('stickers',)] * 3
    return dict(
        id='RU14_Vam_Zakaz', title='Вам заказ', mood='spooky',
        hook=['КАЖДЫЙ ВЕЧЕР МНЕ', 'ПРИВОЗЯТ ЗАКАЗ.', '*Я НИЧЕГО НЕ ЗАКАЗЫВАЛА*'],
        caption='Каждый вечер ровно в 19:00 Маше привозят еду, которую она не заказывала. С записками 😨 Узнала, кто это — и расплакалась.\n\n'
                '#маша #истории #добрыеистории #дослёз #анимация #мультик #бабушка #рек',
        scenes=[
            dict(bg='hall', actors=dict(ma=A('masha', 250, expr='shock'),
                                        k=A('courier', 840, flip=True, expr='smile', hold=('bag', 'ЗАКАЗ', '#d9b98a'))), beats=[
                B('N', 'Каждый вечер, ровно в семь, Маше звонили в дверь.', hook=True, fx='zoom', sfx='ding')]),
            dict(bg='hall', actors=dict(ma=A('masha', 250, expr='shock'),
                                        k=A('courier', 840, flip=True, expr='smile', hold=('bag', 'ЗАКАЗ', '#d9b98a'))), beats=[
                B('K', 'Ваш заказ. Оплачено.'),
                B('MA', 'Я ничего не заказывала!', ma=dict(expr='angry', pose='spread'), k=dict(expr='bored'))]),
            dict(props=dict(b=Pr('box', 540, 1560, label='СУП', w=420, h=300, col='#d9b98a', tcol='#7a4a1e'),
                            n=Pr('note', 540, 1040, text='Поешь|горячего', show=False, rot=-5)), **YELLOW, beats=[
                B('N', 'В пакете был суп. И записка:'),
                B('N', '_«Поешь горячего»_.', n=dict(show=True), sfx='pop', fx='zoom')]),
            dict(props=dict(b=Pr('box', 540, 1560, label='КОТЛЕТЫ', w=420, h=300, col='#d9b98a', tcol='#7a4a1e'),
                            n=Pr('note', 540, 1040, text='Ты совсем|худая!', rot=4)), **YELLOW, beats=[
                B('N', 'На второй день — котлеты. _«Ты совсем худая»_.', sfx='pop')]),
            dict(bg='night_room', bgp=dict(clock='19:00'), dark=0.35, actors=dict(ma=A('masha', expr='scared', pose='cover')),
                 cam=(1.25, 540, 860), beats=[
                B('N', 'Маша испугалась. За ней кто-то *следит*.', sfx='sting', fx='red', ma=dict(shake=4))]),
            dict(bg='hall', actors=dict(ma=A('masha', 250, expr='angry', pose='hips'),
                                        k=A('courier', 840, flip=True, expr='scared', hold=('bag', 'ЗАКАЗ', '#d9b98a'))), beats=[
                B('MA', 'Кто это заказывает?!', fx='shake', sfx='boom'),
                B('K', 'Сказали не говорить. Но это из дома напротив.', k=dict(expr='smile', pose='point', hold=None),
                  ma=dict(expr='shock', pose='idle'))]),
            dict(bg='facade', bgp=dict(lit=[(1, 1)]), mood='warm',
                 actors=dict(b=A('baba', 410, y=838, s=0.3, expr='joy', pose='wave')), cam=(1.6, 440, 760), beats=[
                B('N', 'В доме напротив горело одно окно.', sfx='ding')]),
            dict(chat=ch, mood='warm', **CHATBG, beats=[
                B('B', '«Ты в три ночи не спишь. Значит, и не ешь».', msg=('in', 'Ты в три ночи не спишь. Значит, и не ешь.')),
                B('B', '«Мне 84. Я научилась заказывать».', msg=('in', 'Мне 84. Я научилась заказывать!'))]),
            dict(bg='night_room', bgp=dict(clock='19:07'), mood='warm', dark=0.1,
                 actors=dict(ma=A('masha', expr='cry', hold='phone')), beats=[
                B('N', 'Маша смеялась и плакала. Одновременно.', ma=dict(expr='joy')),
                B('N', 'А потом научила бабушку слать стикеры.', ma=dict(expr='happy', pose='up', hold=None), sfx='pop')]),
            dict(chat=dict(ch, sub='3:00'), mood='comedy', **CHATBG, beats=[
                B('N', '*Зря*.', msg=stickers, sfx='fail', d=1.6),
                B('N', 'Теперь в три ночи их приходит сорок.', msg=stickers, fx='zoom', d=2.6)]),
        ])


def tuk_tuk():
    NR = dict(bg='night_room')
    return dict(
        id='RU15_Tuk_Tuk_Tuk', title='Тук-тук-тук', mood='spooky',
        hook=['КАЖДУЮ НОЧЬ В _3:00_', 'СВЕРХУ СТУЧАТ.', '*НО ТАМ НИКТО НЕ ЖИВЁТ*'],
        caption='Каждую ночь ровно в 3:00 Маше стучат сверху. А квартира наверху пустая уже год 😨 Досмотри — там такой поворот...\n\n'
                '#маша #гоша #страшилки #истории #соседи #анимация #мультик #рек',
        scenes=[
            dict(dark=0.3, actors=dict(ma=A('masha', expr='shock', pose='cover', look=(0, -1))), **NR, beats=[
                B('N', 'Каждую ночь, ровно в три, Машу будил стук.', hook=True, fx=['zoom', 'shake'], sfx=['knock', 'knock@1.6'])]),
            dict(dark=0.3, actors=dict(ma=A('masha', expr='scared', look=(0, -1))), **NR, beats=[
                B('N', 'Три удара. Пауза. Снова три.', big='ТУК-ТУК-ТУК', sfx=['knock', 'knock@1.1'], fx='shake')]),
            dict(bg='hall', bgp=dict(num='48'), actors=dict(ma=A('masha', 250, expr='angry', pose='point')),
                 props=dict(n=Pr('note', 560, 940, text='ХВАТИТ|СТУЧАТЬ!', size=44, rot=6, z=-1)), beats=[
                B('N', 'Маша оставила соседу записку.', sfx='pop')]),
            dict(dark=0.3, actors=dict(ma=A('masha', expr='angry', pose='hips', look=(0, -1))), **NR, beats=[
                B('N', 'Стук не прекратился.', big='ТУК-ТУК-ТУК', sfx='knock', fx='shake')]),
            dict(bg='hall', bgp=dict(num='48'), dark=0.25, actors=dict(ma=A('masha', 220, expr='angry')), beats=[
                B('N', 'Тогда она поднялась наверх.', ma=dict(x=300)),
                B('N', 'Квартира была пустой. Уже *год*.', bgp=dict(open=1), ma=dict(expr='scared', pose='cover'), sfx='sting',
                  fx=['red', 'zoom'])]),
            dict(dark=0.35, actors=dict(ma=A('masha', expr='scared', look=(0, -1))), **NR, beats=[
                B('N', 'Ночью стук вернулся.', sfx='knock', fx='shake'),
                B('N', 'И Маша поняла: стучат не сверху.', ma=dict(expr='shock', look=(0, 0))),
                B('N', 'Стучат *снизу*.', ma=dict(look=(0, 1), expr='scared', shake=6), sfx=['knock', 'sting@0.2'],
                  fx=['shake', 'red'])]),
            dict(bg='hall', bgp=dict(num='44', open=1), mood='comedy',
                 actors=dict(ma=A('masha', 220, expr='scared', s=1.3), g=A('gosha', 680, show=False, expr='bored', hold='mop', s=1.3)), beats=[
                B('N', 'Маша спустилась. Дверь открыл Гоша. Со шваброй.', g=dict(show=True), sfx='fail@0.8'),
                B('G', 'Ты храпишь. Каждую ночь. Ровно в три.', g=dict(expr='angry')),
                B('MA', 'Я?! Я не храплю!', ma=dict(expr='angry', pose='spread'))]),
            dict(mood='comedy', actors=dict(ma=A('masha', 300, expr='shock', pose='cover'),
                                            g=A('gosha', 780, expr='smug', hold='phone')), **YELLOW, beats=[
                B('N', 'Гоша включил запись.', big='ХРРРРР', bigcol='#ffe14d', sfx='snore', fx='shake', d=2.0)]),
            dict(mood='comedy', dark=0.2, actors=dict(ma=A('masha', expr='sleep')),
                 props=dict(z=Pr('text', 760, 880, text='z z Z', size=80, col='#cfe0ff')), **NR, beats=[
                B('N', 'Теперь Маша спит тихо.')]),
            dict(mood='comedy', dark=0.2, actors=dict(g=A('gosha', expr='joy', hold='phone')), **NR, beats=[
                B('N', 'А в три ночи стучит уже _она_.', big='ТУК-ТУК-ТУК', sfx=['knock', 'knock@1.0'], fx='shake',
                  g=dict(expr='shock', look=(0, -1))),
                B('N', 'Гоша смотрит видео без наушников.', g=dict(expr='smug', look=(0, 0)), sfx='fail')]),
        ])


STORIES = [lift, kontrolnaya, holodilnik, magazin, chat_klassa, plackart, ya_znayu, idi_uzhinat, vam_zakaz, tuk_tuk]

CHANNEL = """НАЗВАНИЕ КАНАЛА
Гоша не спит

НИК (@username), варианты на случай, если занято
@gosha.ne.spit
@goshanespit
@ne.bud.kak.gosha

ОПИСАНИЕ ДЛЯ TIKTOK (до 80 символов)
Не будь как Гоша 🚪 Истории в 3:00 с финалом, которого ты не ждёшь

ОПИСАНИЕ ДЛЯ YOUTUBE SHORTS / VK КЛИПОВ / ДЗЕНА
Это Гоша. Гоша нарушает все правила, чтобы тебе не пришлось.
Короткие мультики: «4 правила, которые нарушил Гоша» и истории в 3:00 ночи с неожиданным финалом.
Страшно в начале, смешно в конце. Досмотри до последней секунды: там всегда поворот.
Подпишись, пока в шкафу тихо.

РУБРИКИ
1. «Не будь как Гоша» — 4 правила, и Гоша нарушает каждое.
2. «Ровно в 3:00» — переписки и истории с неожиданным финалом.

ЗАКРЕПЛЁННЫЙ КОММЕНТАРИЙ (ставить под каждым видео)
Какое правило нарушил бы ты? Пиши номер 👇

АВАТАР
avatar.png (1024x1024, лицо Гоши по центру, не обрежется кругом)
"""
