+++
title = "Gaussian bubble clusters"
date = 2020-06-15
+++

Suppose I ask you to divide \\\(\mathbb{R}^n\\\) into two pieces of fixed Gaussian
measure so that the surface area of the boundary is as small as possible.  The
*Gaussian isoperimetric inequality* states that the best way to do it is by
cutting \\\(\mathbb{R}^n\\\) with a hyperplane:

![Gaussian half-space](../halfspace.svg)

Now what if I ask for *three* parts instead of two? <!-- more --> That is: divide
\\\(\mathbb{R}^n\\\) into three pieces of fixed Gaussian measure so as to minimize
the surface area of the boundary. I [solved this
recently](https://arxiv.org/abs/1801.09296) with Emanuel Milman; the answer is
what we call a "tripod" partition (a.k.a.  the "standard Y" or the "peace sign"
partition):

![Gaussian tripod](../tripod.svg)

Ok, but if there are three parts, then why is this called a Gaussian
*double*-bubble? It's from analogy with the (more famous) *Euclidean*
double-bubble problem, which asks for a surface-area-minimizing
partition of \\(\mathbb{R}^n\\)
into three pieces with given Lebesgue measure (one of the measures is
necessarily infinite). We're definitely justified in calling this
a double-bubble problem, because the answer looks like one:

![Euclidean double-bubble](../double-bubble.png)

In the words of all those annoying standardized tests: the Gaussian double
bubble is to the Gaussian isoperimetric inequality as the Euclidean double
bubble is to the Euclidean isoperimetric inequality. That's why we call it
a Gaussian double bubble.

What about more bubbles? In general, multi-bubble problems seem to be hard:
the solution to the Euclidean triple-bubble problem is known only in two
dimensions, and the Euclidean quadruple-bubble is not understood in any setting.
However, a [follow-up paper](https://arxiv.org/abs/1805.10961) by Emanuel Milman and I
solves the Gaussian \\(k\\)-bubble problem in \\(n\\) dimensions
(i.e. we can find the optimal split of \\(\mathbb{R}^n\\) into \\(k+1\\) parts)
whenever \\(n \ge k\\). For example, here's an optimal Gaussian triple bubble
in three dimensions:

![Gaussian triple-bubble](../gaussian-triple-bubble.png)


