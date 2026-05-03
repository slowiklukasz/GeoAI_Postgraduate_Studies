library(tidyverse)

setwd("D:/ProgramowanieR/")

trees <- read.table('./Data/trees.txt',sep = ';',header = T,dec=',')

# ==========================================================================
# PUNKTOWE ----------------------------------------------------------------
# ==========================================================================

# Wykresy wbudowane
plot(trees[,c('h','dbh')])
plot(trees[,c('h','dbh')],xlab='Wysokość [m]',ylab = "Piersnica [cm]",main = "Wykres")

# ggplot
ggplot(data = trees, aes(x=h,y=dbh))

ggplot(data = trees, aes(x=h,y=dbh)) + 
  geom_point() +
  xlab("Wysokość [m]") + 
  ylab("Piersnica [cm]")

ggplot(data = trees, aes(x=h,y=dbh)) + 
  geom_point() +
  xlab("Wysokość [m]") + 
  ylab("Piersnica [cm]") + 
  ggtitle("Wykres")

ggplot(data = trees, aes(x=h,y=dbh)) + 
  geom_point() +
  xlab("Wysokość [m]") + 
  ylab("Piersnica [cm]") + 
  ggtitle("Wykres") +
  theme_light()

# Klasyfikacja punktów po gatunku
ggplot(data = trees, aes(x=h,y=dbh,color=TrSpec)) + 
  geom_point() +
  xlab("Wysokość [m]") + 
  ylab("Piersnica [cm]") + 
  ggtitle("Wykres") +
  theme_light()

# Zmiana tytułu legendy
ggplot(data = trees, aes(x=h,y=dbh,color=TrSpec)) + 
  geom_point() +
  xlab("Wysokość [m]") + 
  ylab("Piersnica [cm]") +
  scale_color_discrete(name = "Gatunek") +
  ggtitle("Wykres") +
  theme_light()

# Zmiana pozycji legendy
ggplot(data = trees, aes(x=h,y=dbh,color=TrSpec)) + 
  geom_point() +
  xlab("Wysokość [m]") + 
  ylab("Piersnica [cm]") +
  scale_color_discrete(name = "Gatunek") +
  ggtitle("Wykres") +
  theme_light() +
  theme(legend.position = "bottom")

ggplot(data = trees, aes(x=h,y=dbh,color=TrSpec)) + 
  geom_point() +
  geom_smooth(method = "lm") +
  xlab("Wysokość [m]") + 
  ylab("Piersnica [cm]") +
  scale_color_discrete(name = "Gatunek") +
  ggtitle("Wykres") +
  theme_light() +
  theme(legend.position = "bottom")

# ==========================================================================
# HISTOGRAM ---------------------------------------------------------------
# ==========================================================================

hist(trees$h)

ggplot(data = trees, aes(x=h)) + 
  geom_histogram()

ggplot(data = trees, aes(x=h)) + 
  geom_histogram(binwidth = 5)

ggplot(data = trees, aes(x=h)) + 
  geom_histogram(color='black',fill='red') +
  scale_x_continuous(name = "Wysokość") + 
  scale_y_continuous(name = 'Liczebność')


ggplot(data = trees, aes(x=h)) + 
  geom_histogram(color='black',fill='red') +
  scale_x_continuous(name = "Wysokość",limits=c(0,30),breaks=c(0:10,15,20,25,30)) + 
  scale_y_continuous(name = 'Liczebność')

# ==========================================================================
# BOXPLOT -----------------------------------------------------------------
# ==========================================================================

ggplot(trees, aes(x=TrSpec, y=h)) + geom_boxplot()
ggplot(trees, aes(x=TrSpec, y=h)) + geom_boxplot() +   coord_flip()

# ==========================================================================
# BARPLOT -----------------------------------------------------------------
# ==========================================================================

ggplot(trees, aes(x=TrSpec)) +
  geom_bar()

ndata <- trees %>% mutate(group = round(h/10)) %>% group_by(group) %>% count

ggplot(ndata, aes(x=group,y = n)) +
  geom_col()

ndata <- trees %>% mutate(group = round(h/10)) %>% group_by(TrSpec,group) %>% count

ggplot(ndata, aes(x=TrSpec, y = n,  fill=group)) +
  geom_col()

ggplot(ndata, aes(x=TrSpec, y = n,  fill=group)) +
  geom_col(position = ) + theme_bw()