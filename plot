#!/usr/bin/env python

import matplotlib.pyplot as pl
import os
import pandas as pd
import seaborn as sn
import sys

df = pd.read_table(sys.stdin)

if "dated" in sys.argv:
    label = df.columns[0]
    df[label] = pd.to_datetime(df[label])
    df = df.set_index(label)

df.plot()
pl.savefig("plot.png")
os.system("open plot.png")

