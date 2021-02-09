#!/bin/bash
set -e

CORES=$(expr $(nproc) - 1)
TYPE=$1
MAIN_DIR=$PWD
GIZA_DIR="giza-pp"
MOSES_DIR="mosesdecoder"

if [[ $TYPE == "--help" || $TYPE == "-h" || $TYPE == "" ]]; then
cat << EOF
    --short     Wytrenuj mały zbiór 10k
    --long      Wytrenuj średni zbiór 20k
    --clean     Wyczyść pliki
EOF
    exit
fi

if [[ $TYPE != "--short" && $TYPE != "--long" && $TYPE != "--clean" ]]; then
    echo "Brak opcji"
    exit
fi

if [[ $TYPE == "--clean" ]]; then
    # TODO? git reset
    exit
fi

if ! [[ -d $GIZA_DIR ]]; then
    git clone https://github.com/moses-smt/giza-pp.git
    cd $GIZA_DIR
    make -j$CORES
    cd $MAIN_DIR
fi

if ! [[ -d $MOSES_DIR ]]; then
    git clone https://github.com/moses-smt/mosesdecoder.git
    cd $MOSES_DIR
    ./bjam -j$CORES
    cd $MAIN_DIR
fi

if ! [[ -d $MOSES_DIR/tools ]]; then
    cd $MOSES_DIR
    mkdir tools
    cp $MAIN_DIR/$GIZA_DIR/GIZA++-v2/GIZA++ $MAIN_DIR/$GIZA_DIR/GIZA++-v2/snt2cooc.out \
        $MAIN_DIR/$GIZA_DIR/mkcls-v2/mkcls tools
    cd $MAIN_DIR
fi


CORPUS="$MAIN_DIR/train"
cd $CORPUS

if ! [[ -f news-commentary.pl-en.en ]]; then
    xz -d < expected.tsv.xz > expected.tsv
    mv expected.tsv news-commentary.pl-en.en
fi

if ! [[ -f news-commentary.pl-en.pl ]]; then
    xz -d < in.tsv.xz > in.tsv
    mv in.tsv news-commentary.pl-en.pl
fi


# news-commentary.pl-en.pl
# news-commentary.pl-en.en

if [[ $TYPE == "--short" ]]; then
    sed -i '10000,$d' news-commentary.pl-en.en
    sed -i '10000,$d' news-commentary.pl-en.pl
fi

if [[ $TYPE == "--long" ]]; then
    sed -i '20000,$d' news-commentary.pl-en.en
    sed -i '20000,$d' news-commentary.pl-en.pl
fi



# cd $MAIN_DIR
if ! [[ -f $CORPUS/news-commentary.pl-en.tok.pl ]]; then
 $MAIN_DIR/$MOSES_DIR/scripts/tokenizer/tokenizer.perl -l pl \
    < $CORPUS/news-commentary.pl-en.pl    \
    > $CORPUS/news-commentary.pl-en.tok.pl
fi


if ! [[ -f $CORPUS/news-commentary.pl-en.tok.en ]]; then
 $MAIN_DIR/$MOSES_DIR/scripts/tokenizer/tokenizer.perl -l en \
    < $CORPUS/news-commentary.pl-en.en    \
    > $CORPUS/news-commentary.pl-en.tok.en
fi

if ! [[ -f $CORPUS/truecase-model.pl ]]; then
 $MAIN_DIR/$MOSES_DIR/scripts/recaser/train-truecaser.perl \
     --model $CORPUS/truecase-model.pl --corpus     \
     $CORPUS/news-commentary.pl-en.tok.pl
fi

if ! [[ -f $CORPUS/truecase-model.en ]]; then
 $MAIN_DIR/$MOSES_DIR/scripts/recaser/train-truecaser.perl \
     --model $CORPUS/truecase-model.en --corpus     \
     $CORPUS/news-commentary.pl-en.tok.en
fi

if ! [[ -f $CORPUS/news-commentary.pl-en.true.pl ]]; then

 $MAIN_DIR/$MOSES_DIR/scripts/recaser/truecase.perl \
   --model $CORPUS/truecase-model.pl         \
   < $CORPUS/news-commentary.pl-en.tok.pl \
   > $CORPUS/news-commentary.pl-en.true.pl

fi

if ! [[ -f $CORPUS/news-commentary.pl-en.true.en ]]; then

 $MAIN_DIR/$MOSES_DIR/scripts/recaser/truecase.perl \
   --model $CORPUS/truecase-model.en         \
   < $CORPUS/news-commentary.pl-en.tok.en \
   > $CORPUS/news-commentary.pl-en.true.en

fi

if ! [[ -f $CORPUS/news-commentary.pl-en.clean.pl ]]; then

 $MAIN_DIR/$MOSES_DIR/scripts/training/clean-corpus-n.perl \
    $CORPUS/news-commentary.pl-en.true pl en \
    $CORPUS/news-commentary.pl-en.clean 1 80
fi

LM_DIR="lm"
if ! [[ -d $MAIN_DIR/$LM_DIR ]]; then
    mkdir $MAIN_DIR/$LM_DIR
fi

cd $MAIN_DIR/$LM_DIR

if ! [[ -f news-commentary.pl-en.arpa.en ]]; then
    $MAIN_DIR/$MOSES_DIR/bin/lmplz -o 3 < $CORPUS/news-commentary.pl-en.true.en > news-commentary.pl-en.arpa.en
fi


if ! [[ -f news-commentary.pl-en.blm.en ]]; then

$MAIN_DIR/$MOSES_DIR//bin/build_binary \
   news-commentary.pl-en.arpa.en \
   news-commentary.pl-en.blm.en
fi

WORK_DIR="working"

if ! [[ -d $MAIN_DIR/$WORK_DIR ]]; then
    mkdir $MAIN_DIR/$WORK_DIR
fi

cd $MAIN_DIR/$WORK_DIR

if ! [[ -f training.out ]]; then

    nohup nice $MAIN_DIR/$MOSES_DIR/scripts/training/train-model.perl -root-dir train \
    -corpus $CORPUS/news-commentary.pl-en.clean -cores $CORES                            \
    -f pl -e en -alignment grow-diag-final-and -reordering msd-bidirectional-fe \
    -lm 0:3:$MAIN_DIR/$LM_DIR/news-commentary.pl-en.blm.en:8                          \
    -external-bin-dir $MAIN_DIR/$MOSES_DIR/tools >& training.out 
fi

DEV_DIR="$MAIN_DIR/dev-0"


cd $DEV_DIR
[[ -f news-test.en ]] || cp expected.tsv news-test.en
[[ -f news-test.pl ]] || cp in.tsv news-test.pl

cd $CORPUS

if ! [[ -f news-test.tok.en ]]; then

$MAIN_DIR/$MOSES_DIR/scripts/tokenizer/tokenizer.perl -l en \
   < $DEV_DIR/news-test.en > news-test.tok.en
 $MAIN_DIR/$MOSES_DIR/scripts/tokenizer/tokenizer.perl -l pl \
   < $DEV_DIR/news-test.pl > news-test.tok.pl
 $MAIN_DIR/$MOSES_DIR/scripts/recaser/truecase.perl --model truecase-model.en \
   < news-test.tok.en > news-test.true.en
 $MAIN_DIR/$MOSES_DIR/scripts/recaser/truecase.perl --model truecase-model.pl \
   < news-test.tok.pl > news-test.true.pl
fi



cd $MAIN_DIR/$WORK_DIR

if ! [[ -f mert.out ]]; then
nohup nice $MAIN_DIR/$MOSES_DIR/scripts/training/mert-moses.pl --decoder-flags="-threads $CORES" \
  $CORPUS/news-test.true.pl $CORPUS/news-test.true.en \
  $MAIN_DIR/$MOSES_DIR/bin/moses train/model/moses.ini --mertdir $MAIN_DIR/$MOSES_DIR/bin/ \
  &> mert.out
fi



TEST_DIR="$MAIN_DIR/test-A"

 cd $TEST_DIR

 if ! [[ -f newstest.pl ]]; then
    cp in.tsv newstest.pl
 fi

if ! [[ -f newstest.tok.pl ]]; then
    $MAIN_DIR/$MOSES_DIR/scripts/tokenizer/tokenizer.perl -l pl \
    < newstest.pl > newstest.tok.pl
    $MAIN_DIR/$MOSES_DIR/scripts/recaser/truecase.perl --model $CORPUS/truecase-model.pl \
    < newstest.tok.pl > newstest.true.pl
fi


 cd $MAIN_DIR/$WORK_DIR

 $MAIN_DIR/$MOSES_DIR/scripts/training/filter-model-given-input.pl             \
   filtered-newstest mert-work/moses.ini $TEST_DIR/newstest.true.pl \


nohup nice $MAIN_DIR/$MOSES_DIR/bin/moses            \
   -f $MAIN_DIR/$WORK_DIR/filtered-newstest/moses.ini   \
   < $TEST_DIR/newstest.true.pl                \
   > $MAIN_DIR/$WORK_DIR/newstest.translated.en         \
   2> $MAIN_DIR/$WORK_DIR/newstest.out 

cp $MAIN_DIR/$WORK_DIR/newstest.translated.en $TEST_DIR/out.tsv

cd $DEV_DIR

 $MAIN_DIR/$MOSES_DIR/scripts/tokenizer/tokenizer.perl -l en \
   < $DEV_DIR/news-test.en > news-test.tok.en
 $MAIN_DIR/$MOSES_DIR/scripts/tokenizer/tokenizer.perl -l pl \
   < $DEV_DIR/news-test.pl > news-test.tok.pl
 $MAIN_DIR/$MOSES_DIR/scripts/recaser/truecase.perl --model $CORPUS/truecase-model.en \
   < news-test.tok.en > news-test.true.en
$MAIN_DIR/$MOSES_DIR/scripts/recaser/truecase.perl --model $CORPUS/truecase-model.pl \
   < news-test.tok.pl > news-test.true.pl

#  cd $MAIN_DIR/$WORK_DIR
#  $MAIN_DIR/$MOSES_DIR/scripts/training/filter-model-given-input.pl             \
#    filtered-newstest mert-work/moses.ini $DEV_DIR/news-test.true.pl


nohup nice $MAIN_DIR/$MOSES_DIR/bin/moses            \
   -f $MAIN_DIR/$WORK_DIR/filtered-newstest/moses.ini   \
   < $DEV_DIR/news-test.true.pl                \
   > $MAIN_DIR/$WORK_DIR/newstest.translated.en         \
   2> $MAIN_DIR/$WORK_DIR/newstest.out 


cp $MAIN_DIR/$WORK_DIR/newstest.translated.en $DEV_DIR/out.tsv


alert fin