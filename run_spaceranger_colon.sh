#!/usr/bin/env bash
set -euo pipefail

#################### 固定路径与参数 ####################
SRC=/mnt/taobo.hu/long/10X_datasets/Visium/Visium_HD/Visium_HD_Human_Colon_Cancer
SAMPLE=Visium_HD_Human_Colon_Cancer

OUT=/data/taobo.hu/5K_HD            # 可写输出根目录，改成 Colon_HD
ID=colon_prime5k_sr4_cell             # Space Ranger --id，自定义即可
REF=$HOME/ref/refdata-gex-GRCh38-2024-A  # 参考基因组目录（保持不变）

CORES=16          # CPU 线程
MEM=128           # 内存 (GB)

#################### 创建工作目录 ####################
mkdir -p "$OUT/fastqs" "$OUT/tmp"

#################### 1) 解包 FASTQ ###################
echo "[Step] untar FASTQ..."
tar -xf "$SRC/${SAMPLE}_fastqs.tar" -C "$OUT/fastqs"

#################### 2) 转 BTF → TIFF ################
echo "[Step] convert BTF → TIFF..."
BFDIR=$OUT/tmp/bftools
TIFF=$OUT/${SAMPLE}_HiRes_HE.tif

# Java 运行时（缺则临时装一份）
if ! command -v java &>/dev/null; then
  echo "  [Info] installing OpenJDK17 via conda..."
  conda install -qy -c conda-forge openjdk=17
fi

# bfconvert（如无则下载）
if [ ! -x "$BFDIR/bfconvert" ]; then
  echo "  [Info] downloading Bio-Formats CLI ..."
  mkdir -p "$BFDIR"
  wget -q https://downloads.openmicroscopy.org/bio-formats/6.11.0/artifacts/bftools.zip \
       -O "$OUT/tmp/bftools.zip"
  unzip -q -o "$OUT/tmp/bftools.zip" -d "$BFDIR"
  chmod +x "$BFDIR/bfconvert"
fi
export PATH="$BFDIR:$PATH"

# 若 TIFF 已存在且非空就跳过；否则重新转换
if [ ! -s "$TIFF" ]; then
  echo "  [Info] generating HiRes_HE.tif ..."
  bfconvert "$SRC/${SAMPLE}_tissue_image.btf" "$TIFF"
else
  echo "  [Info] HiRes_HE.tif already exists — skip conversion"
fi

#################### 3) 运行 Space Ranger #############
echo "[Step] run spaceranger count..."
cd "$OUT"

spaceranger count \
  --id="$ID" \
  --create-bam=false \
  --transcriptome="$REF" \
  --probe-set="$SRC/${SAMPLE}_probe_set.csv" \
  --fastqs="$OUT/fastqs/${SAMPLE}_fastqs" \
  --image="$TIFF" \
  --cytaimage="$SRC/${SAMPLE}_image.tif" \
  --jobmode=local \
  --localcores="$CORES" \
  --localmem="$MEM"

echo "==> 运行完成！结果目录:  $OUT/$ID/outs/"
