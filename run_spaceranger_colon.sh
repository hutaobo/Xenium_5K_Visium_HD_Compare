#!/usr/bin/env bash
set -euo pipefail

#################### Fixed paths and parameters ####################
SRC=/mnt/taobo.hu/long/10X_datasets/Visium/Visium_HD/Visium_HD_Human_Colon_Cancer
SAMPLE=Visium_HD_Human_Colon_Cancer

OUT=/data/taobo.hu/5K_HD            # writable output root directory (change to Colon_HD)
ID=colon_prime5k_sr4_cell           # Space Ranger --id (customizable)
REF=$HOME/ref/refdata-gex-GRCh38-2024-A  # reference genome directory (unchanged)

CORES=16          # CPU threads
MEM=128           # memory (GB)

#################### Create working directories ####################
mkdir -p "$OUT/fastqs" "$OUT/tmp"

#################### 1) Unpack FASTQ ####################
echo "[Step] untar FASTQ..."
tar -xf "$SRC/${SAMPLE}_fastqs.tar" -C "$OUT/fastqs"

#################### 2) Convert BTF → TIFF ####################
echo "[Step] convert BTF → TIFF..."
BFDIR=$OUT/tmp/bftools
TIFF=$OUT/${SAMPLE}_HiRes_HE.tif

# Java runtime (install temporarily if missing)
if ! command -v java &>/dev/null; then
  echo "  [Info] installing OpenJDK17 via conda..."
  conda install -qy -c conda-forge openjdk=17
fi

# bfconvert (download if missing)
if [ ! -x "$BFDIR/bfconvert" ]; then
  echo "  [Info] downloading Bio-Formats CLI ..."
  mkdir -p "$BFDIR"
  wget -q https://downloads.openmicroscopy.org/bio-formats/6.11.0/artifacts/bftools.zip \
       -O "$OUT/tmp/bftools.zip"
  unzip -q -o "$OUT/tmp/bftools.zip" -d "$BFDIR"
  chmod +x "$BFDIR/bfconvert"
fi
export PATH="$BFDIR:$PATH"

# Skip if TIFF already exists and is non-empty; otherwise convert
if [ ! -s "$TIFF" ]; then
  echo "  [Info] generating HiRes_HE.tif ..."
  bfconvert "$SRC/${SAMPLE}_tissue_image.btf" "$TIFF"
else
  echo "  [Info] HiRes_HE.tif already exists — skip conversion"
fi

#################### 3) Run Space Ranger ####################
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

echo "==> DONE! Output directory:  $OUT/$ID/outs/"
