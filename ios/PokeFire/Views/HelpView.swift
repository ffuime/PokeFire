import SwiftUI

private struct HelpItem: Identifiable {
    var id: String { term }
    let term: String
    let text: String
}

private struct HelpTopic: Identifiable {
    let id: String
    let title: String
    let icon: String
    let lead: String
    var items: [HelpItem] = []
    var points: [String] = []
    var note: String?
}

private let helpTopics: [HelpTopic] = [
    HelpTopic(
        id: "screen",
        title: "画面の見方",
        icon: "help",
        lead: "上から、天候・フィールド、加算計算のタブ、攻撃側と防御側の切り替えが並び、その下に各ポケモンの設定、画面下に結果カードがあります。",
        items: [
            HelpItem(term: "攻撃側・防御側", text: "左右にスワイプするか、上部の切り替えバーをタップしてパネルを切り替えます。"),
            HelpItem(term: "攻守交代", text: "切り替えバー中央の ⇄ で攻撃側と防御側のポケモンを入れ替えます。調整はそれぞれのポケモンに付いたまま入れ替わります。定数のタブを選んでいる間は使えません。"),
            HelpItem(term: "履歴", text: "左上のボタンか、画面の左端から右へスワイプすると開きます。"),
            HelpItem(term: "PokéStats", text: "ポケモンの画像を長押しするか、パネルのいちばん上からさらに引っ張って離すと、使用率やタイプ相性を見る PokéStats に切り替わります。戻るときも同じ操作です。PokéStats で変えたポケモンや能力ポイントはダメージ計算には反映されません。"),
            HelpItem(term: "結果カード", text: "いつも画面下に表示されている計算結果です。タップで詳細、長押しで共有などのメニューが開きます。"),
        ]
    ),
    HelpTopic(
        id: "pokemon",
        title: "ポケモンを選ぶ",
        icon: "search",
        lead: "ポケモン名をタップすると一覧が開きます。一覧はシングルの使用率順で、メガシンカは元のポケモンのすぐ下に並びます。",
        points: [
            "ひらがな・カタカナ・ローマ字・よく使われる略称で検索できます。",
            "キーボードの検索ボタンで、一覧の一番上のポケモンに決まります。",
            "「履歴」に切り替えると、最近選んだポケモンが並びます。",
            "選ぶと、使用率1位のとくせいと、使用率がいちばん高い攻撃技（攻撃側のみ）が自動で入ります。もちものは使用率1位がこのアプリで扱えるものの場合だけ入り、それ以外は「なし」になります。",
            "能力ポイントと性格は、ポケモンごとに前回の調整を覚えています。初めて選んだポケモンは H2・A32・C32・ほかは0 です。",
            "画像をタップすると、同じ図鑑番号のほかの姿（メガシンカ・リージョンフォームなど）が並びます。",
            "タイプをタップするとタイプを付けたり外したりできます。「リセット」で本来のタイプに戻ります。",
        ]
    ),
    HelpTopic(
        id: "stats",
        title: "能力ポイント・性格・ランク",
        icon: "edit",
        lead: "選んだわざに合わせて、必要な能力だけが表示されます（物理なら攻撃側は A、防御側は H・B など）。",
        items: [
            HelpItem(term: "能力ポイント", text: "バーをタップするか横になぞって 0〜32 を指定します。右上に実数値が表示されます。"),
            HelpItem(term: "性格補正", text: "×0.9・×1.0・×1.1 から選びます。"),
            HelpItem(term: "ランク", text: "−と＋で −6〜+6 を指定します。数字をタップすると直接選べます。上がっていると赤、下がっていると青になります。"),
            HelpItem(term: "のこりHP", text: "防御側は常に、攻撃側はふんか・しおふき・じたばた・きしかいせい・いのちがけ・がむしゃらのときに表示されます。"),
        ]
    ),
    HelpTopic(
        id: "move",
        title: "わざ",
        icon: "tab_attack",
        lead: "わざの欄をタップすると検索が開きます。上には選んでいるポケモンがよく使うわざが、使用率付きで並びます。右上の威力は今の条件で変わった威力で、元より上がっていると赤字になります。",
        items: [
            HelpItem(term: "急所", text: "急所に当たったときの計算になります。こおりのいぶき・トリックフラワー・やまあらしは必ず急所なので、鍵が付いて固定されます。"),
            HelpItem(term: "威力アップ", text: "相手が地中にいるときのじしんなど、条件で威力が上がるわざのときだけ表示されます。"),
            HelpItem(term: "連続技", text: "急所の代わりに「ヒット回数」「急所回数」が表示されます。タップするか、横になぞって回数を変えられます。2〜5回のわざは2回、ネズミざんは10回が初期値で、スキルリンクなら5回で固定です。"),
            HelpItem(term: "トリプルアクセル", text: "1〜3回目それぞれの「ヒット」「急所」を個別に切り替えられます。"),
        ]
    ),
    HelpTopic(
        id: "ability",
        title: "とくせい・もちもの・じょうたい",
        icon: "lock",
        lead: "候補をタップするか、検索から選びます。",
        items: [
            HelpItem(term: "とくせい", text: "条件付きで効くとくせい（もうか・マルチスケイルなど）には「発動」ボタンが付きます。常に効くとくせいは鍵付きで固定されます。へんげんじざい・リベロは「タイプ変更」で今のわざのタイプになり、いかく・まけんきなどは「発動」でランクが変わります。ひでり・○○メイカーなどは「発動」で天候・フィールドが変わり、ばけのかわは「発動」で直前に1/8の定数ダメージタブを作ります。"),
            HelpItem(term: "もちもの", text: "メガシンカのポケモンを選ぶと自動で「メガストーン」になります。メトロノームのときは「連続攻撃回数」を指定できます。"),
            HelpItem(term: "じょうたい", text: "攻撃側は「やけど」「じゅうでん」「地面にいる」、防御側は「リフレクター」「ひかりのかべ」「地面にいる」「無防備状態」を切り替えられます。からげんき・こんじょうのときは、やけどの半減が関係ないので鍵が付きます。"),
        ]
    ),
    HelpTopic(
        id: "environment",
        title: "天候・フィールド",
        icon: "weather_sun",
        lead: "上部中央のボタンから設定します。選んでいるものをもう一度タップすると「なし」に戻ります。"
    ),
    HelpTopic(
        id: "order",
        title: "加算計算（タブ）",
        icon: "tab_damage",
        lead: "上部の＋で、攻撃・定数ダメージ・定数回復のタブを今のタブの次に追加できます。タブを長押しすると、順番の入れ替えや削除ができます。タブが2つ以上あると、結果は並び順どおりに当てたときの「ひんし率」になります。",
        points: [
            "防御側のポケモンはすべてのタブで共通です。",
            "同じポケモンなら、もちもの・とくせい・能力ポイント・性格はタブ同士で共通です。",
            "タイプ・ランク・わざ・じょうたい・とくせいの発動は、タブごとに別々に持てます。",
        ]
    ),
    HelpTopic(
        id: "constant",
        title: "定数ダメージ・定数回復",
        icon: "tab_heel",
        lead: "定数のタブを選ぶと、攻撃側のパネルが専用の画面になります。防御側の最大HPを基準に計算し、右上に合計を表示します。",
        items: [
            HelpItem(term: "割合", text: "1/32〜1/2 などの割合ごとに、受けた（回復した）回数を −＋ で指定します。各行には当てはまる例が書いてあります。"),
            HelpItem(term: "もうどく", text: "ダメージのみ。1〜15ターン目それぞれの回数を指定します。"),
            HelpItem(term: "固定", text: "50ダメージ（ちきゅうなげ・ナイトヘッド）や10回復（オレンのみ）の回数と、好きな量を追加して入力できます。"),
        ],
        note: "回復は減っているHPの分までしか入らず、ひんしになった後は回復しません。"
    ),
    HelpTopic(
        id: "result",
        title: "結果カード・ダメージの詳細",
        icon: "speed",
        lead: "結果カードには最大HPに対する割合とダメージ量、HPバー、判定が表示されます。濃い部分が確実に残るHP、薄い部分が乱数次第で残るHPです。",
        items: [
            HelpItem(term: "判定", text: "攻撃1つのときは「確定○発」「乱数○発（確率）」、タブが2つ以上のときは「ひんし率」を表示します。"),
            HelpItem(term: "フロー", text: "詳細では、タブの順に攻撃が並びます。タップすると、その攻撃だけの結果と乱数表（85〜100%）・補正の一覧が開きます。∑を選ぶと全体の結果に戻ります。"),
            HelpItem(term: "攻撃側の反動・回復", text: "吸収わざ・反動わざ・いのちのたま・かいがらのすず・おおきなねっこ、相手のゴツゴツメット・さめはだなどによるHPの増減です。"),
            HelpItem(term: "ダメージ反射・調整ライン", text: "カウンター・メタルバーストなどで返されるダメージと、確定1発・確定耐えに必要な能力ポイントを表示します。"),
            HelpItem(term: "すばやさ比較", text: "スピードのボタンから開きます。グラフをなぞると、その実数値になる能力ポイントと性格の組み合わせが表示されます。"),
            HelpItem(term: "共有", text: "詳細の右上や結果カードの長押しから、今の計算条件をそのまま開けるURLを送れます。URLはWeb版でも開けます。"),
        ]
    ),
    HelpTopic(
        id: "history",
        title: "履歴",
        icon: "history",
        lead: "計算した対面は自動で履歴に残ります（最大60件）。タップするとその条件に戻ります。",
        points: [
            "右にスワイプでピン留め、左にスワイプで削除します。",
            "長押しでプレビューと、共有などのメニューが開きます。",
            "アプリを閉じても、次に開いたときは前回の状態から始まります。",
        ]
    ),
    HelpTopic(
        id: "spec",
        title: "計算の仕様",
        icon: "add",
        lead: "第9世代のダメージ計算式に準拠しています。補正は 4096 を1倍とする方式で、各段階の丸めも本作の計算どおりに行います。",
        items: [
            HelpItem(term: "実数値（レベル50）", text: "H = 種族値 + 75 + 能力ポイント\nH以外 = (種族値 + 20 + 能力ポイント) × 性格補正（切り捨て）"),
            HelpItem(term: "火力指数", text: "補正後の攻撃の実数値 × 補正後の威力 × タイプ一致 × 天候 × 攻撃側の最終補正 × 急所 × やけど。相手によって変わる補正は含みません。連続技は全ヒットの合計です。"),
            HelpItem(term: "表記", text: "%は小数第1位まで（四捨五入）、乱数○発の確率だけ小数第2位までです。"),
        ],
        note: "カウンター・ミラーコート・メタルバースト・ほうふく・はきだす・なげつける・ふくろだたきなど、一部のわざは計算できません。"
    ),
    HelpTopic(
        id: "data",
        title: "データの出典",
        icon: "share",
        lead: "Pokéloot は非公式のファンツールです。株式会社ポケモン・任天堂・クリーチャーズ・ゲームフリークとは関係ありません。",
        points: [
            "わざ・とくせい・もちもの・ポケモンのデータは、GameWith の攻略情報をもとにしています。",
            "ポケモンの画像は PokéAPI のスプライト、検索用の略称はポケソルのデータを使用しています。",
            "使用率は Pokémon Champions Battle Data のシングルのデータを使用しています（Battle data provided by Pokémon Champions Battle Data）。",
            "英語名と日本語名の対応には PokéAPI のデータを使用しています。",
        ]
    ),
]

private let statsTopics: [HelpTopic] = [
    HelpTopic(
        id: "stats-screen",
        title: "画面と切り替え",
        icon: "help",
        lead: "PokéStats は、ポケモンの種族値・タイプ相性・使用率をまとめて見るための画面です。攻撃側と防御側の2体を左右にスワイプして見比べられます。",
        items: [
            HelpItem(term: "切り替え", text: "ポケモンの画像を長押しするか、パネルの一番上からさらに下へ引っ張り、ゲージがいっぱいの状態で指を離すと PokéFire に戻ります。左上のメニューやサイドバーからも切り替えられます。"),
            HelpItem(term: "ダメ計との関係", text: "PokéStats で変えたポケモンや能力ポイントは、ダメージ計算には反映されません。「このポケモンでダメ計する」を押すと、その内容で PokéFire に移ります。"),
            HelpItem(term: "履歴", text: "PokéStats で見た2体の組み合わせは、ダメ計とは別の履歴に残ります。"),
        ]
    ),
    HelpTopic(
        id: "stats-base",
        title: "種族値と調整",
        icon: "edit",
        lead: "種族値の下に、能力ポイントと性格補正を反映した実数値が「176(+32↑)」の形で表示されます。",
        points: [
            "種族値をタップすると吹き出しが開き、能力ポイントと性格補正を変えられます。",
            "すばやさの吹き出しでは、素早さ特性とランクを指定できます。これは吹き出しの中の実数値とすばやさラインだけに反映されます。",
            "「PokéBoxに追加」で、今の調整のまま PokéBox に登録できます。",
        ]
    ),
    HelpTopic(
        id: "stats-type",
        title: "とくせい・タイプ相性",
        icon: "shield",
        lead: "とくせいをタップすると効果と、そのとくせいを持つポケモンが使用率順に並びます。ポケモンをタップするとそのポケモンに切り替わります。",
        points: [
            "タイプ相性は、受けるダメージの倍率ごとにタイプが並びます。見出しをタップすると最小化できます。",
            "「とくせいを考慮」をオンにすると、ふゆう・ちょすい・あついしぼうなど、相性が変わるとくせいを反映します。該当するとくせいがないポケモンでは表示されません。",
        ]
    ),
    HelpTopic(
        id: "stats-usage",
        title: "バトルデータ",
        icon: "speed",
        lead: "Pokémon Champions Battle Data のシングルのデータをもとに、わざ・とくせい・もちもの・能力補正・能力ポイントの採用率を表示します。",
        points: [
            "わざをタップすると、タイプ・分類・威力・命中・PP・効果を確認できます。",
            "円グラフをタップすると項目名が出て、そこをタップすると詳細が開きます。円グラフ以外をタップすると一覧が開きます。",
            "のうりょくポイントの行をタップすると、その配分をお手本として反映できます。",
        ]
    ),
    HelpTopic(
        id: "stats-speed",
        title: "すばやさライン",
        icon: "speed",
        lead: "すばやさの吹き出しや、すばやさ比較の画面から開けます。実数値ごとに、どのポケモンがどの配分でその値になるかが並びます。",
        points: [
            "最遅は青、無振は灰、準速は緑、最速は赤で表示します。スカーフ・素早さ特性・すばやさを上げる積み技も含みます。",
            "開いたときは、今のポケモンの実数値の位置まで自動でスクロールします。",
            "行をタップすると、そのポケモンと配分に切り替わります。",
            "右下のスイッチで、使用率TOP50だけに絞り込めます。",
        ]
    ),
    HelpTopic(
        id: "stats-learnset",
        title: "覚えるわざ",
        icon: "search",
        lead: "「覚えるわざを見る」から、そのポケモンが覚えるわざの一覧を開けます。行をタップすると詳細が開きます。",
        points: [
            "検索欄の右のボタンから、タイプ・分類・威力・命中・PP・優先度・対象・追加効果などで絞り込めます。",
            "同じ見出しの中でオンにした条件は「どれか」、見出しどうしは「すべて」に当てはまるものが残ります。",
        ]
    ),
]

private let boxTopics: [HelpTopic] = [
    HelpTopic(
        id: "box-home",
        title: "ボックスとチーム",
        icon: "help",
        lead: "PokéBox では、育成したポケモンを登録してチームを組めます。下のタブで「ボックス」と「チーム」を切り替えます。",
        points: [
            "右下の＋で、ボックスではポケモンを、チームではチームを作成します。",
            "検索欄にポケモン名を入れると、そのポケモンを含むものに絞り込めます。",
            "右上のボタンで並び替えと選択ができます。選択中はまとめて削除でき、ボックスでは6体以下を選ぶとチームを作れます。",
            "行を左にスワイプで削除、右にスワイプでお気に入り・複製です。長押しでも同じ操作ができます。",
        ]
    ),
    HelpTopic(
        id: "box-edit",
        title: "ポケモンの編集",
        icon: "edit",
        lead: "ポケモンを選ぶと編集画面が開きます。とくせいには使用率1位、メガシンカならもちものにメガストーンが自動で入ります。",
        points: [
            "種族値をタップすると能力ポイントの調整が開きます。合計は66まで、各能力は32までです。上部の配分ボタンで使用率上位の配分を入れられます。",
            "性格補正は×1.1と×0.9がそれぞれ1つまでです。片方だけ決めると、使用率が一番高い組み合わせが自動で入ります。",
            "わざは4つまで選べます。わざ選択の画面で「三」をドラッグすると並び替えられます。",
            "ニックネーム欄の右の輝きボタンで、色違いを切り替えられます。",
        ]
    ),
    HelpTopic(
        id: "box-thumbnail",
        title: "サムネイル",
        icon: "share",
        lead: "編集画面の上部に、ポケモンの情報をまとめたサムネイルが表示されます。",
        points: [
            "サムネイルの各部分をタップすると、その項目の編集が開きます。",
            "長押しすると、サムネイルを画像として写真に保存できます。",
        ]
    ),
    HelpTopic(
        id: "box-team",
        title: "チーム",
        icon: "tab_attack",
        lead: "チームには、ボックスのポケモンを最大6体まで入れられます。チームのポケモンはボックスの個体と同じもので、編集するとボックスにも反映されます。",
        points: [
            "チームのサムネイルをタップすると拡大して見られます。ピンチで拡大し、ポケモンをタップするとそのポケモンの編集に移ります。",
            "チームのサムネイルを長押しすると、画像として保存できます。設定で縦長の並びにもできます。",
            "チームのポケモンの編集中は、サムネイルを横にスワイプすると隣のポケモンに移れます。",
            "下部には、チームが苦手なタイプと、苦手なポケモンが表示されます。",
        ]
    ),
]

private let dataTopics: [HelpTopic] = [
    HelpTopic(
        id: "data-home",
        title: "PokéData の使い方",
        icon: "search",
        lead: "4つのボタンから、ポケモン・わざ・とくせい・もちものの検索画面を開きます。",
        points: [
            "ポケモンは、タイプ・内定かどうか・メガシンカ・とくせい・覚えるわざ・種族値・重さで絞り込み、図鑑番号・使用率・各種族値などで並べ替えられます。タップするとそのポケモンを PokéStats で開きます。",
            "わざは、タイプ・分類・威力・命中・PP・優先度・対象・追加効果で絞り込めます。タップすると詳細が開きます。",
            "とくせいともちものは、実装済みかどうかで絞り込めます。とくせいはタップすると効果と持っているポケモンが表示されます。",
        ]
    ),
]

private struct HelpService: Identifiable {
    let id: String
    let title: String
    let symbol: String?
    let image: String?
    let tint: Color
    let summary: String
    let topics: [HelpTopic]
}

private let helpServices: [HelpService] = [
    HelpService(id: "fire", title: "PokéFire", symbol: nil, image: "tab_attack", tint: Palette.attack, summary: "ダメージと火力指数を計算します。乱数・確定数・加算計算・反動や回復までまとめて確認できます。", topics: helpTopics.filter { $0.id != "data" }),
    HelpService(id: "stats", title: "PokéStats", symbol: "chart.pie", image: nil, tint: Palette.accent, summary: "種族値・タイプ相性・使用率・すばやさラインなど、ポケモンの情報を見比べます。", topics: statsTopics),
    HelpService(id: "data", title: "PokéData", symbol: "books.vertical", image: nil, tint: Color(hex: 0xE09A1B), summary: "ポケモン・わざ・とくせい・もちものを、細かい条件で検索できる図鑑です。", topics: dataTopics),
    HelpService(id: "box", title: "PokéBox", symbol: "cube.box", image: nil, tint: Color(hex: 0x20A6A6), summary: "育成したポケモンを登録してチームを組み、サムネイル画像として保存できます。", topics: boxTopics),
]

private let allTopics: [HelpTopic] = helpTopics + statsTopics + dataTopics + boxTopics

struct HelpView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Pokéloot")
                            .font(.largeTitle.weight(.bold))
                            .foregroundStyle(Palette.ink)
                        Text("ポケモンチャンピオンズのシングルバトルのためのツールです。ダメージ計算の PokéFire、ポケモンの情報を見る PokéStats、図鑑検索の PokéData、育成したポケモンとチームを管理する PokéBox の4つのサービスがあり、左上のメニューやサイドバーから切り替えられます。")
                            .font(.subheadline)
                            .foregroundStyle(Palette.secondary)
                    }
                    .padding(.vertical, 8)
                }
                Section("サービス") {
                    ForEach(helpServices) { service in
                        NavigationLink(value: "service:" + service.id) {
                            HStack(alignment: .top, spacing: 12) {
                                Group {
                                    if let image = service.image {
                                        Icon(name: image, size: 18)
                                    } else if let symbol = service.symbol {
                                        Image(systemName: symbol)
                                            .font(.system(size: 17, weight: .semibold))
                                    }
                                }
                                .foregroundStyle(service.tint)
                                .frame(width: 36, height: 36)
                                .background(Circle().fill(service.tint.opacity(0.12)))
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(service.title)
                                        .font(.headline)
                                        .foregroundStyle(Palette.ink)
                                    Text(service.summary)
                                        .font(.caption)
                                        .foregroundStyle(Palette.secondary)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
                Section {
                    NavigationLink(value: "topic:data") {
                        Label {
                            Text("データの出典")
                                .foregroundStyle(Palette.ink)
                        } icon: {
                            Icon(name: "share", size: 20)
                                .foregroundStyle(Palette.accent)
                        }
                    }
                    Link(destination: URL(string: "https://ffui.me/poke/fire/")!) {
                        Label {
                            Text("Web版を開く")
                        } icon: {
                            Icon(name: "share", size: 18)
                        }
                    }
                } footer: {
                    Text("© 2026 fifth.")
                }
            }
            .navigationDestination(for: String.self) { value in
                if value.hasPrefix("service:"), let service = helpServices.first(where: { "service:" + $0.id == value }) {
                    HelpServiceView(service: service)
                } else if let topic = allTopics.first(where: { "topic:" + $0.id == value }) {
                    HelpTopicView(topic: topic)
                }
            }
            .navigationTitle("ヘルプ")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    CloseToolbarButton { dismiss() }
                }
            }
        }
        .presentationDragIndicator(.visible)
    }
}

private struct HelpServiceView: View {
    let service: HelpService

    var body: some View {
        List {
            Section {
                Text(service.summary)
                    .font(.subheadline)
                    .foregroundStyle(Palette.secondary)
                    .padding(.vertical, 4)
            }
            Section("もくじ") {
                ForEach(service.topics) { topic in
                    NavigationLink(value: "topic:" + topic.id) {
                        Label {
                            Text(topic.title)
                                .foregroundStyle(Palette.ink)
                        } icon: {
                            Icon(name: topic.icon, size: 20)
                                .foregroundStyle(service.tint)
                        }
                    }
                }
            }
        }
        .navigationTitle(service.title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct HelpTopicView: View {
    let topic: HelpTopic

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text(topic.lead)
                    .font(.body)
                    .foregroundStyle(Palette.ink)
                    .fixedSize(horizontal: false, vertical: true)
                if !topic.items.isEmpty {
                    VStack(alignment: .leading, spacing: 14) {
                        ForEach(topic.items) { item in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(item.term)
                                    .font(.subheadline.weight(.bold))
                                    .foregroundStyle(Palette.accent)
                                Text(item.text)
                                    .font(.subheadline)
                                    .foregroundStyle(Palette.ink)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                    .card()
                }
                if !topic.points.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(topic.points, id: \.self) { point in
                            HStack(alignment: .firstTextBaseline, spacing: 8) {
                                Circle()
                                    .fill(Palette.accent)
                                    .frame(width: 6, height: 6)
                                    .alignmentGuide(.firstTextBaseline) { $0[.bottom] }
                                Text(point)
                                    .font(.subheadline)
                                    .foregroundStyle(Palette.ink)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                    .card()
                }
                if let note = topic.note {
                    Text(note)
                        .font(.footnote)
                        .foregroundStyle(Palette.secondary)
                        .padding(14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Palette.accent.opacity(0.06), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
            }
            .padding(16)
        }
        .background(Palette.background)
        .navigationTitle(topic.title)
        .navigationBarTitleDisplayMode(.inline)
    }
}
