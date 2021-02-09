
wmt-2020-pl-en
==========================================

Translate from Polish to English.

This is a challenge created from http://www.statmt.org/wmt20/translation-task.html . Train set is created from europarl wmt pl-en training data. Dev and test set are created from wmt pl-en development data.

Directory structure
-------------------

* `README.md` — this file
* `config.txt` — configuration file
* `train/` — directory with training data
* `train/train.tsv` — sample parallel corpus (Finnish text in the first column, Māori text in the second one)
* `dev-0/` — directory with dev (test) data
* `dev-0/in.tsv` — Finnish input text for the dev set
* `dev-0/expected.tsv` — Māori reference translation for the dev set
* `test-A` — directory with test data
* `test-A/in.tsv` — Finnish input data for the test set
* `test-A/expected.tsv` — Māori reference translation for the test set
