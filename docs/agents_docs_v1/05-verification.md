# 05 — Verification (eval engineering)

How to check that the loop actually produced correct work: LLM-as-judge
calibration (judges are noisy and biased — run both ways, majority vote, freeze
rubrics) and agent-generated test suites that push coverage deep into code.

## 2082193490956476521 — @Argona0x
- url: https://x.com/i/status/2082193490956476521
- posted_at: Tue Jul 28 19:56:28 +0000 2026
- kind: tweet

> whoever leaked this has bigger balls than sense
>
> two researchers replaced $7,500 of human grading with $77.81 of model calls, and the number that fell out should stop anyone shipping an agent this week: the judge disagrees with itself 13.6% of the time
>
> it also prefers whichever answer it saw first, 72% of the time. cross-judge agreement is a kappa of 0.51: the statistical polite word for guessing
>
> this is Eval Engineering, the layer that arrives after loops and graphs, and it installs into the agent you already pay for:
>
> - run every comparison both ways and average the two, because one production judge picked whichever answer sat in the first slot 72% of the time
> - stop shipping on a single verdict: recovering the reference answer took 11 repeated trials before a majority vote landed it, and 15 on the questions that actually mattered
> - report the chance-corrected agreement instead of raw match, since the gap between those two ran 33 to 41 points on the same benchmark
> - never let a model grade its own family, because self-preference tracks capability upward rather than falling away as models improve
> - test stability and bias together, since two judges already running in production held above 0.95 on repeat while carrying severe positional preference
> - freeze the rubric wording and version it, because semantically identical templates flipped the majority outcome in a quarter of tested cases
> - write the rubric as one observable pass condition rather than a bundle of scores, so a coin-flip preference cannot hide inside an average
> - let plain code take every objective call, did the test pass, does the file exist, did the state change, and leave the judge only what genuinely needs reading
> - make the verdict do something structural to the run in flight, reject the handoff, swap the node, quarantine the branch, or you have built a dashboard
>
> the catch is that your judge is a measurement instrument nobody calibrates: single-trial judging is too noisy for anything you would stake money on, and the same judges reordered by as much as 14 positions depending on which benchmark you asked
>
> so the loop has to converge on the spec rather than on the score, because optimise against a judge long enough and the agent learns to look right instead of being right
>
> bookmark this, the full build with the five evals to start on and the gate that lets the fleet merge its own work is written out in the article ↓

## 2084768844615413960 — @iwashi86
- url: https://x.com/i/status/2084768844615413960
- posted_at: Tue Aug 04 22:30:00 +0000 2026
- kind: tweet

> AIでCOBOLからJavaへコード移植する方法の提案論文。
>
> ・レガシーなCOBOLからJavaへの移行は、テストデータ不足で隅々まで検証するのが難しい
> ・そこで Locksmith Loop と呼ばれるAIエージェントによるテスト生成手法を提案
>
> ・COBOLと生成されたJavaの双方にモックを組み込んで実行環境を用意
> ・エージェントが入力値の探索と変異を反復し、プログラムの条件分岐の奥深くまで入り込む
> ・探索がブロックされた条件を特定して突破することで、カバレッジを広げていく
>
> ・今回は、430〜4,114行規模の3つのCOBOLプログラムでケーススタディを実施した
> ・結果として、オープンソースのプログラム2つではほぼ完全な網羅率に到達
> ・実稼働相当の内製プログラムでも91.90%の分岐カバレッジを達成した
>
> https://arxiv.org/abs/2607.28271
