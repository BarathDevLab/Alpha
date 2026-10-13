#!/usr/bin/env python3
"""
train_baseline.py
=================
Trains a char n-gram TF-IDF + Logistic Regression classifier for Mind Guard.
Ships as the production fallback (no BERT needed).

Usage
-----
    pip install scikit-learn pandas numpy
    python ml/train_baseline.py

Output
------
    assets/mind_model.json   — vocab, idf weights, LR coef + intercept, class names

Classes
-------
    safe    = 0
    concern = 1
    high    = 2
"""

import csv
import json
import os
import sys
from pathlib import Path

import numpy as np
import pandas as pd
from sklearn.feature_extraction.text import TfidfVectorizer
from sklearn.linear_model import LogisticRegression
from sklearn.metrics import classification_report
from sklearn.model_selection import train_test_split
from sklearn.pipeline import Pipeline
from sklearn.preprocessing import LabelEncoder

# ── Paths ─────────────────────────────────────────────────────────────────────
ROOT = Path(__file__).resolve().parent.parent
SEED_CSV = ROOT / "assets" / "mind_seed.csv"
OUT_JSON = ROOT / "assets" / "mind_model.json"

# ── Load data ─────────────────────────────────────────────────────────────────
print("Loading data …")
rows = []
with open(SEED_CSV, encoding="utf-8") as f:
    reader = csv.DictReader(f)
    for row in reader:
        text = row["text"].strip()
        label = row["label"].strip()
        if text and label:
            rows.append({"text": text, "label": label})

df = pd.DataFrame(rows)
print(f"  {len(df)} examples  |  classes: {df['label'].value_counts().to_dict()}")

# ── Optional: load a public dataset if present beside the seed ────────────────
PUBLIC_CSV = ROOT / "ml" / "public_dataset.csv"
if PUBLIC_CSV.exists():
    pub = pd.read_csv(PUBLIC_CSV)
    # Expect columns: text, label (same encoding)
    pub = pub[["text", "label"]].dropna()
    df = pd.concat([df, pub], ignore_index=True)
    print(f"  Public dataset merged → {len(df)} total examples")

# ── Split ─────────────────────────────────────────────────────────────────────
X_train, X_test, y_train, y_test = train_test_split(
    df["text"], df["label"],
    test_size=0.20,
    stratify=df["label"],
    random_state=42,
)
print(f"  Train: {len(X_train)}  Test: {len(X_test)}")

# ── Model ─────────────────────────────────────────────────────────────────────
print("\nTraining TF-IDF + LogisticRegression …")
vectorizer = TfidfVectorizer(
    analyzer="char_wb",
    ngram_range=(1, 3),
    max_features=8_000,
    sublinear_tf=True,
)
clf = LogisticRegression(C=1.0, max_iter=1000, multi_class="multinomial", solver="lbfgs")

pipe = Pipeline([("tfidf", vectorizer), ("lr", clf)])
pipe.fit(X_train, y_train)

# ── Evaluate ──────────────────────────────────────────────────────────────────
print("\nEvaluation on held-out 20 %:")
y_pred = pipe.predict(X_test)
print(classification_report(y_test, y_pred, digits=3))

# ── Export ────────────────────────────────────────────────────────────────────
tfidf = pipe.named_steps["tfidf"]
lr    = pipe.named_steps["lr"]

vocab = {term: int(idx) for term, idx in tfidf.vocabulary_.items()}
idf   = tfidf.idf_.tolist()
coef  = lr.coef_.tolist()
intercept = lr.intercept_.tolist()
classes   = lr.classes_.tolist()

model_data = {
    "vocab": vocab,
    "idf":   idf,
    "coef":  coef,
    "intercept": intercept,
    "classes":   classes,
}

OUT_JSON.parent.mkdir(parents=True, exist_ok=True)
with open(OUT_JSON, "w", encoding="utf-8") as f:
    json.dump(model_data, f, ensure_ascii=False, separators=(",", ":"))

size_kb = OUT_JSON.stat().st_size / 1024
print(f"\nExported → {OUT_JSON}  ({size_kb:.1f} KB)")
print("Done ✓")
