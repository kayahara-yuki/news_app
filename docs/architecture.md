# SwiftUI 時代のアーキテクチャ選定

**タグ:** アーキテクチャ, Swift, SwiftUI, iOS アプリ設計パターン入門  
**最終更新日:** 2025 年 03 月 09 日  
**投稿日:** 2025 年 03 月 05 日

## まえがき

こんにちは。ゆざく@Zack-yutapon です

3 年前に Swift を始めたときにはなかなか理解ができなかった、『iOS アプリ設計パターン入門』。ちょっと時間ができたので、クリーンアーキテクチャ以降をしっかり理解しようと紐解いたところ、宣言的な記載や View とデータの双方向バインディングを実現した SwiftUI では、たとえば MVP や VIPER に使われる「Presenter」のような、データと View を切り離す発想はアンチパターンとなっていないか、と気づきました。

そこで、各アーキテクチャの特徴と、SwiftUI で実装したらどうなるかをぐろ君(旧 Twitter、現 X の AI)に聞き、これがかなり納得のゆく結果だったので記事にまとめてみます。

## この記事について

この記事では、『iOS アプリ設計パターン入門』の記載順序に従って、1.GUI アーキテクチャ(MVP,MVVM)、2.システムアーキテクチャの理解(CleanArchitecture) 3.画面遷移パターン(Rooter,VIPER※,Coordinator)の順で、SwiftUI にどのように適応するか、または適さないかを、ざっくりまとめます。

※VIPER については、書籍では MVP+Rooter で理解できるだろうとのことで割愛されています。

なおアーキテクチャの設計により、開発過程のチェッキングやテスティングが容易になるメリットも認識はしていますが、記事が膨大になるため本記事ではスコープ外とし、あくまでアーキテクチャ選定に焦点を当てております。

また、私自身 Swift 経験は個人開発のみであるため、コメントをいただいても適切な返答ができない場合も考えられますが、この記事やコメント欄を通じ、Qiita や Twitter などで日本人の Swift 開発者の議論や検討が進めば幸いです。

**◎3/6 追記:** コメント指摘やコメントで頂いた動画では、書籍にない単なる「MV」とのアーキテクチャパターンの表現もあります。その方が適切かもしれないですが、アーキテクチャについては UIKit 時代の当該書籍をもとに理解を進めている Swift エンジニアが大半の現状、悩ましいですが本記事では便宜上「MVVM」としての記載をそのまま使うことにします。

**◎3/9 追記:** 上記のコメントを追記しましたが、再度丁寧なコメント返信をいただき、「MVVM」とするのはふさわしくないとの判断に至りました。本記事の結論として「MVVM」をベストプラクティスと記載したものの、アーキテクチャの状況を調査した中で(※)、「MV」を選択する企業が散見されます。

## 目次

1. モデルと View を切り離す「GUI アーキテクチャ」
   - 1.1. MVP と SwiftUI
   - 1.2. MVVM と SwiftUI
   - 1 章まとめ(MVP と MVVM の相違点)
   - 1 章の最後に
2. システムアーキテクチャ
   - 2.1 CleanArchitecture
   - まとめ
3. 画面遷移を扱うアーキテクチャ
   - 3.1.VIPER と SwiftUI
   - 3.2.Router と SwiftUI
   - 3.3.Coordinator と SwiftUI
   - 3 章のまとめ
4. SwiftUI 時代の設計指針
5. その他のアーキテクチャ
   - 5.1. TCA (The Composable Architecture)
   - 5.2. RIBs (Router-Interactor-Builder)
6. 本記事のまとめ
7. 最後に(謝辞)

## 1. モデルと View を切り離す「GUI アーキテクチャ」

書籍では、前段として View と Model を切り離す「GUI アーキテクチャ」の考え方、次に View を切り離した上で、Model をどう扱うかの議論としてシステムアーキテクチャの考え方を説明していた。この記事でもこの流れに沿って、View⇔Model を切り離す役割を持つ「Presenter」をおく MVP と、View⇔Model 双方向を紐づける ViewModel を持つ MVVM のアーキテクチャを比較する。

### 1.1. MVP と SwiftUI

MVP（Model-View-Presenter）は、Presenter が View を制御するアーキテクチャ。具体的には、UI 層とロジック層を分離するためのアーキテクチャで、以下の構成となる。

**構成：**

- **Model:** データやビジネスロジック（例: ToDo アイテムの保存や取得）
- **View:** UI そのもの（例: SwiftUI の View）
- **Presenter:** View と Model をつなぐ仲介者。View に依存せず、ロジックを処理して View に表示用のデータを渡す

**Presenter の役割:**

- View からの入力を受けてビジネスロジックを実行
- Model から取得したデータを View が表示しやすい形に変換
- View に対して命令的な操作（「これを表示しろ」と指示）を出す

**具体的な動き:**

- Presenter が主導: Presenter が View を制御し、表示用のデータを準備
- View は受動的: View は Presenter の命令に従うだけ（displayTodos など）
- 双方向の接続: Presenter が View を弱参照で持ち、View が Presenter を強参照で持つ

**コード例:**

```swift
// Presenter
class TodoPresenter {
    private let repository: TodoRepository
    weak var view: TodoViewProtocol?

    init(repository: TodoRepository) {
        self.repository = repository
    }

    func loadTodos() {
        let todos = repository.fetchTodos()
        view?.displayTodos(todos: todos.map { $0.title })
    }

    func addTodo(title: String) {
        repository.saveTodo(TodoItem(id: UUID().uuidString, title: title))
        loadTodos()
    }
}

protocol TodoViewProtocol: AnyObject {
    func displayTodos(todos: [String])
}

// View
struct TodoView: View, TodoViewProtocol {
    private let presenter: TodoPresenter
    @State private var todos: [String] = []

    init(presenter: TodoPresenter) {
        self.presenter = presenter
        presenter.view = self
    }

    var body: some View {
        NavigationView {
            List(todos, id: \.self) { todo in
                Text(todo)
            }
            .navigationTitle("ToDo List")
            .toolbar {
                Button("Add") {
                    presenter.addTodo(title: "New Task")
                }
            }
            .onAppear { presenter.loadTodos() }
        }
    }

    func displayTodos(todos: [String]) {
        self.todos = todos
    }
}
```

**MVP でなぜ情報変更ごとに「loadTodos」を呼ぶのか?**

MVP では、Presenter が View を制御する役割を持つ。このため、データ（Model）が変更された場合、Presenter がその変更を検知し、View に新しいデータを反映するよう命令を出す必要が生じる。

例：ユーザーが新しい ToDo を追加したとき、Presenter は addTodo を実行した後に loadTodos を呼び出して、最新の状態を View に渡す。

**SwiftUI での評価**

- **課題:** Presenter が手動で View を更新（loadTodos を毎回呼ぶ）する必要があり、SwiftUI 固有の@Published の自動性が活かせない
- **結論:** SwiftUI の双方向バインディングと相性が悪く、メリットが薄い

### 1.2. MVVM と SwiftUI

MVVM（Model-View-ViewModel）は、ViewModel が状態を管理し、データのバインディングを活用して UI とロジックを分離するアーキテクチャ。

**構成：**

- **Model:** データやビジネスロジック
- **View:** UI そのもの
- **ViewModel:** View のためのデータを公開し、状態を管理。View と双方向でデータを同期

**ViewModel の役割：**

- Model からデータを取得し、View がそのまま使える形で公開（通常は@Published で状態を管理）
- View からの入力を処理し、Model を更新
- データバインディングを通じて、UI と自動的に同期

**具体的な動き：**

- ViewModel が状態を公開: @Published でデータを公開し、View がそれを監視
- View が能動的: View が ViewModel の状態変化に反応して UI を更新
- 一方向の依存: View が ViewModel に依存するが、ViewModel は View を知らない

**SwiftUI での評価**

- **利点:** @Published で状態を公開し、SwiftUI が自動反映。シンプルで自然
- **結論:** SwiftUI に最適。状態駆動型設計と親和性が高い

### 1 章まとめ(MVP と MVVM の相違点)

**相違点の整理**

| 項目           | Presenter (MVP)                      | ViewModel (MVVM)                   |
| -------------- | ------------------------------------ | ---------------------------------- |
| 役割           | View と Model の仲介者。View を制御  | View のためのデータと状態の管理    |
| View との関係  | 双方向（Presenter が View を参照）   | 一方向（View が ViewModel を監視） |
| データ処理     | View 用にデータを変換して渡す        | 生データやそのまま使える状態を公開 |
| 制御の主体     | Presenter が主導。View は受動的      | View が状態変化に反応              |
| バインディング | 明示的な命令（メソッド呼び出し）     | 自動同期（SwiftUI の@Published）   |
| 依存性         | Presenter が View のプロトコルに依存 | ViewModel は View に依存しない     |

**選定基準のまとめ**

小さな ToDo アプリなら、SwiftUI の特性を活かして MVVM の方が実装が簡潔で直感的。MVP は少し手動感が強くなり、Presenter と View の接続を手動で管理する必要が生じる。

## 2. システムアーキテクチャ

### 2.1 CleanArchitecture

まず、なぜシステムアーキテクチャを検討する必要があるか。なぜ階層構造を持たせる必要があるのか。

『iOS アプリ設計パターン入門』の 10 章『Clean Architecture』の章の冒頭に

> この構造を維持してアプリケーションを作ることで、変わりやすい部分を変えやすく、維持しておきたい部分はそのままにしやすくできます。また、内側にある Entity や Use Case は外側の Web API サーバーやデバイスドライバなどに依存していないので、それらの完成を待つことなくロジックをテストできます。これが Clean Architecture の特徴です。

との記載があり、これは UIKit⇒SwiftUI に移行後も同様に有用な発想かと思われる。

**構成(MVVM×CleanArchitecture とした)**

- **Entity:** 純粋なデータ構造（例: TodoItem）
- **UseCase:** ビジネスロジック（例: TodoUseCase）
- **Repository:** データ操作の抽象（例: TodoRepository）
- **ViewModel:** UI と UseCase をつなぐ（SwiftUI 特化）

**SwiftUI でのポイント**

- UseCase が Repository の抽象（プロトコル）に依存し、具体的な実装は分離
- ViewModel が SwiftUI の@Published を活用し、状態を自動同期

### まとめ

書籍のコードでは、View に対してはこの穴と端子を Repository(Entity)⇔UseCase、UseCase⇔View の二段構えにしていたが、SwiftUI においては UseCase⇔View を切り離す Presenter を省き ViewModel のインスタンス化時に ViewModel(usecase: usecase)のようにすれば済むため、CleanArchitecture は以前より軽量な実装が可能になった。

## 3. 画面遷移を扱うアーキテクチャ

### 3.1. VIPER と SwiftUI

UIKit においては、なんか全部実現できそうであった VIPER。View、Interactor、Presenter、Entity、Router の 5 層で構成。

**SwiftUI での問題点:**

1. **Presenter の命令的スタイルと SwiftUI のリアクティブ性の不一致**
2. **Router の役割の減少**
3. **モジュール過多による複雑さ**

**SwiftUI での評価**

- **結論:** 完全適用はオーバーキル。Interactor（UseCase）のみ取り入れる軽量化が現実的

### 3.2. Router と SwiftUI

**Router の目的と役割(UIKit)**

- 画面遷移ロジックの分離
- モジュール間の疎結合
- テスト容易性の向上
- 大規模アプリでのナビゲーション管理

**SwiftUI での適性**

- 宣言的ナビゲーションとのギャップ
- 状態駆動型のアプローチ
- シンプルなアプリではオーバーヘッド

**結論:** 宣言的ナビゲーションと状態駆動型設計により、独立した Router の必要性が減る

### 3.3. Coordinator と SwiftUI

**Coordinator の目的と役割**

- ナビゲーションの抽象化
- フローの制御
- モジュール性
- 疎結合

**SwiftUI での評価**

- **意義の薄れ:** NavigationLink や状態駆動型ナビゲーションで単純な遷移は View 内で完結
- **有効性:** 条件付き分岐や複雑なフローを管理する際に有用

## 4. SwiftUI 時代の設計指針

**小さなアプリ:** MVVM + クリーンアーキテクチャが最適

**中規模アプリ:**

- A. 軽量なクリーンアーキテクチャ: UseCase と Repository を活用して依存性を整理
- B. MVVM + Repository: まだモジュール性が低く、シンプルなデータ操作で済むとき
- C. 状態管理が複雑なら TCA も有力

**大規模アプリ:** CleanArchitecture を採用し、依存性注入コンテナを検討

## 5. その他のアーキテクチャ

### 5.1. TCA (The Composable Architecture)

**概要:** Point-Free が提唱するアーキテクチャ。状態管理と副作用を一元化し、Redux に似た単方向データフローを採用。

**構造:**

- **State:** アプリの全状態を 1 つの構造体で管理
- **Action:** ユーザーの操作やイベントを列挙
- **Reducer:** 状態とアクションを受け取り、次の状態を生成
- **Store:** 状態を保持し、View に公開

**SwiftUI での有効性:**

- 状態の一元管理が強力で、副作用の扱いも整理
- 中〜大規模アプリで状態が複雑化する際に特に有用

### 5.2. RIBs (Router-Interactor-Builder)

**概要:** Uber が開発したアーキテクチャ。Router、Interactor、Builder を中心に、モジュール性を重視。

**構造:**

- **Router:** ナビゲーションや子 RIB の管理を担当
- **Interactor:** ビジネスロジックを処理し、状態を管理
- **Builder:** RIB の依存性を構築
- **View:** UI を表示

**有効性:**

- **利点:** 大規模アプリでモジュール性が求められる場合、依存性構築とフロー管理が有用
- **課題:** 小〜中規模では、NavigationLink で済む遷移を Router で管理するのはオーバーヘッド

## 本記事のまとめ

アーキテクチャの大まかなまとめは 4 章に記載した通りです。TCA の詳細や、UIKit 混在のアプリではどうすべきか、Swift6 時代ではどのような差分が生じるかなど興味はつきませんが、すでに 16,000 字程度となったこと、私自身の知識や技術の限界もあり、一旦ここまでで筆を置くことにします。

## 最後に(謝辞)

AI で手軽に専門知識のまとめができるようになった昨今、文章の長さや目次からは一見充実したコンテンツに見えても、同じ文言を繰り返しており内容の薄い記事が散見されるようになりました。そのような中、本記事引用元のような、検討を重ね推敲の手間をかけた各エンジニアブログの執筆者様皆様には、本当に頭が下がります。

そして、『iOS アプリ設計パターン入門』著者の皆様。Swift エンジニアは日本でも人数が非常に限られ、なおかつ個人開発では、学習は非常に困難をきわめました。この中で、日本語で書かれた『iOS アプリ設計パターン入門』は、私にとって大きな希望であり指標でもありました。

業務に追われる中執筆いただき、ありがとうございました。皆様を個別にフォローさせていただいていますが、この場を借りて御礼申し上げます。

エンジニアの業務は体調を崩すこともあるかと思いますが、どうかご自愛くださいませ。
