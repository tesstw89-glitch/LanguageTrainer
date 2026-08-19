import Foundation

enum CorrelationExclusions {
    static let french = """
de la
de l’
de ce
de cet
de cette
de ces
à la
à l’
à ce
à cet
à cette
à ces
dans le
dans la
dans l’
dans les
dans un
dans une
dans des
sur le
sur la
sur l’
sur les
sur un
sur une
sous le
sous la
sous l’
sous les
avec le
avec la
avec l’
avec les
avec un
avec une
avec des
sans le
sans la
sans l’
sans les
pour le
pour la
pour l’
pour les
pour un
pour une
pour des
par le
par la
par l’
par les
chez le
chez la
chez l’
chez les
entre le
entre la
entre les
vers le
vers la
vers les
ce que
ce qui
ce dont
ce à
que je
que tu
qu’il
qu’elle
qu’on
que nous
que vous
qu’ils
qu’elles
que ça
qui je
qui me
qui te
qui lui
qui nous
qui vous
qui se
qui est
qui sont
qui a
qui ont
dont je
dont tu
dont il
dont elle
dont on
dont nous
dont vous
dont ils
où je
où tu
où il
où elle
où on
où nous
où vous
où ils
lequel est
laquelle est
lesquels sont
lesquelles sont
je me
je te
je le
je la
je lui
je les
je leur
je nous
je vous
je m’
je t’
je l’
je n’
tu me
tu te
tu le
tu la
tu lui
tu les
tu leur
tu nous
tu vous
tu m’
tu t’
tu l’
tu n’
il me
il te
il se
il le
il la
il lui
il les
il leur
il nous
il vous
il s’
il l’
il n’
elle me
elle te
elle se
elle le
elle la
elle lui
elle les
elle leur
elle nous
elle vous
elle s’
elle l’
elle n’
on me
on te
on se
on le
on la
on lui
on les
on leur
on nous
on vous
on s’
on l’
on n’
ça me
ça te
ça se
ça le
ça la
ça lui
ça les
ça nous
ça vous
ça s’
ça l’
nous nous
vous vous
me le
me la
me les
me lui
me l’
te le
te la
te les
te l’
se le
se la
se les
se l’
nous le
nous la
vous le
vous la
le lui
la lui
les lui
le leur
la leur
les leur
je suis
tu es
il est
elle est
on est
nous sommes
vous êtes
ils sont
elles sont
j’ai un
j’ai une
j’ai des
j’ai le
j’ai la
tu as
il a
elle a
on a
nous avons
vous avez
ils ont
je vais
tu vas
il va
elle va
on va
nous allons
vous allez
ils vont
je peux
tu peux
il peut
on peut
je veux
tu veux
il veut
on veut
pas le
pas la
pas les
pas un
pas une
pas de
pas du
est-ce que
est-ce que je
est-ce que tu
est-ce qu’il
est-ce qu’elle
est-ce qu’on
est-ce que ça
est-ce que nous
est-ce que vous
est-ce qu’ils
est-ce qu’elles
est-ce que le
est-ce que la
est-ce que l’
est-ce que les
est-ce que un
est-ce que une
est-ce que des
est-ce que ce
est-ce que cet
est-ce que cette
est-ce que ces
est-ce que c’est
est-ce qu’il y
ce que je
ce que tu
ce qu’il
ce qu’elle
ce qu’on
ce que nous
ce que vous
ce qu’ils
ce que ça
ce qui me
ce qui te
ce qui lui
ce qui nous
ce qui vous
ce qui se
ce qui est
ce qui a
ce qui fait
ce qui va
tout ce que
tout ce qui
de ce que
de ce qui
à ce que
avec ce que
avec ce qui
pour ce que
pour ce qui
sans ce que
sans ce qui
sur ce que
sur ce qui
le truc que
la chose que
les gens qui
celui qui est
celle qui est
ceux qui sont
celles qui sont
parce que je
parce que tu
parce qu’il
parce qu’elle
parce qu’on
parce que ça
parce que nous
parce que vous
parce qu’ils
quand je suis
quand tu es
quand il est
quand on est
quand je vais
quand tu vas
quand on va
quand j’ai
quand tu as
quand on a
si je suis
si tu es
si on est
si j’ai
si tu as
si on a
si je vais
si tu vas
si on va
si je peux
si tu peux
si on peut
comme je suis
comme tu es
comme on est
puisque je suis
puisque tu es
puisque c’est
que je suis
que tu es
qu’il est
qu’elle est
qu’on est
que j’ai
que tu as
qu’il a
qu’on a
que je vais
que tu vas
qu’on va
que je peux
que tu peux
qu’on peut
que je veux
que tu veux
qu’on veut
que je dois
que tu dois
qu’on doit
que je fais
que tu fais
qu’on fait
que je sais
que tu sais
qu’on sait
que je peux pas
que tu peux pas
qu’on peut pas
que je veux pas
que tu veux pas
que je sais pas
que tu sais pas
je me suis
tu t’es
il s’est
elle s’est
on s’est
nous nous sommes
vous vous êtes
ils se sont
je l’ai
tu l’as
il l’a
elle l’a
on l’a
je lui ai
tu lui as
on lui a
ça m’a
ça t’a
ça lui a
ça nous a
tout ce que je
tout ce que tu
tout ce qu’on
tout ce qui est
tout ce qui se
ce que je suis
ce que tu es
ce que je veux
ce que tu veux
ce que je peux
ce que tu peux
ce que j’ai
ce que tu as
ce que je fais
ce que tu fais
ce qui est le
ce qui est la
ce qui est un
ce qui est une
est-ce que je peux
est-ce que tu peux
est-ce qu’on peut
est-ce que je dois
est-ce que tu veux
est-ce que vous avez
est-ce que ça te
parce que je suis
parce que tu es
parce que j’ai
parce que tu as
parce que je peux
parce que je veux
parce que c’est pas
quand je suis allé
quand je suis arrivée
quand je suis chez
quand je vais au
si je peux pas
si tu peux pas
si je veux pas
si tu veux pas
si j’ai pas
si t’as pas
même si je suis
même si tu es
"""

    static let spanish = """
de la
de los
de las
de un
de una
de unos
de unas
a la
a los
a las
a un
a una
a unos
a unas
en el
en la
en los
en las
en un
en una
en unos
en unas
con el
con la
con los
con las
con un
con una
con unos
con unas
por el
por la
por los
por las
por un
por una
por unos
por unas
para el
para la
para los
para las
para un
para una
para unos
para unas
sin el
sin la
sin los
sin las
sin un
sin una
sin unos
sin unas
sobre el
sobre la
sobre los
sobre las
sobre un
sobre una
entre el
entre la
entre los
entre las
entre un
entre una
desde el
desde la
desde los
desde las
hasta el
hasta la
hasta los
hasta las
hacia el
hacia la
hacia los
hacia las
contra el
contra la
contra los
contra las
bajo el
bajo la
bajo los
bajo las
tras el
tras la
tras los
tras las
al que
al cual
del que
del cual
de que
a que
en que
con que
por que
de qué
a qué
en qué
con qué
por qué
para qué
sobre qué
desde qué
hasta qué
de quién
a quién
con quién
en quién
por quién
para quién
lo que
el que
la que
los que
las que
lo cual
el cual
la cual
los cuales
las cuales
de quien
a quien
con quien
en quien
por quien
para quien
que me
que te
que se
que lo
que la
que los
que las
que le
que les
que nos
que os
que no
que sí
que ya
que también
que tampoco
que es
que son
que está
que están
que estaba
que estaban
que hay
que había
que ha
que han
que habían
que puede
que pueden
que podía
que podían
qué me
qué te
qué se
qué lo
qué la
qué los
qué las
qué le
qué les
qué nos
qué os
qué es
qué son
qué está
qué están
qué hay
qué ha
qué han
cómo me
cómo te
cómo se
cómo lo
cómo la
cómo los
cómo las
cómo le
cómo les
cómo nos
cómo os
cómo es
cómo son
cómo está
cómo están
cómo ha
cómo han
cuándo me
cuándo te
cuándo se
cuándo lo
cuándo la
cuándo le
cuándo nos
cuándo os
cuándo es
cuándo son
cuándo está
cuándo están
cuándo ha
cuándo han
dónde me
dónde te
dónde se
dónde lo
dónde la
dónde le
dónde nos
dónde os
dónde está
dónde están
dónde hay
cuál es
cuál está
cuáles son
cuáles están
quién es
quién está
quiénes son
quiénes están
no me
no te
no se
no lo
no la
no los
no las
no le
no les
no nos
no os
no es
no son
no está
no están
no hay
no ha
no han
me lo
me la
me los
me las
te lo
te la
te los
te las
se lo
se la
se los
se las
nos lo
nos la
nos los
nos las
os lo
os la
os los
os las
me le
te le
se le
nos le
os le
se me
se te
se nos
se os
se les
me ha
te ha
se ha
lo ha
la ha
le ha
nos ha
os ha
les ha
me han
te han
se han
lo han
la han
le han
nos han
os han
les han
es el
es la
es los
es las
es un
es una
es unos
es unas
es lo
son los
son las
son unos
son unas
está el
está la
está en
están los
están las
hay un
hay una
hay unos
hay unas
de lo que
a lo que
en lo que
con lo que
lo que me
lo que te
lo que se
lo que lo
lo que la
lo que le
lo que nos
lo que os
lo que les
lo que no
lo que sí
lo que ya
lo que también
lo que es
lo que son
lo que está
lo que están
lo que hay
lo que ha
lo que han
el que me
el que te
el que se
el que lo
el que la
el que le
el que no
el que es
el que está
la que me
la que te
la que se
la que lo
la que la
la que le
la que no
la que es
la que está
los que me
los que te
los que se
los que no
los que son
los que están
las que me
las que te
las que se
las que no
las que son
las que están
de la que
de los que
de las que
a la que
a los que
a las que
en el que
en la que
en los que
en las que
con el que
con la que
con los que
con las que
por el que
por la que
por los que
por las que
para el que
para la que
para los que
para las que
sobre el que
sobre la que
sobre los que
sobre las que
que me ha
que te ha
que se ha
que lo ha
que la ha
que le ha
que nos ha
que os ha
que les ha
que me han
que te han
que se han
que lo han
que la han
que le han
que nos han
que os han
que les han
que no me
que no te
que no se
que no lo
que no la
que no los
que no las
que no le
que no les
que no nos
que no os
que me lo
que me la
que me los
que me las
que te lo
que te la
que te los
que te las
que se lo
que se la
que se los
que se las
que nos lo
que nos la
que os lo
que os la
de qué me
de qué te
de qué se
de qué lo
de qué la
de qué le
a qué me
a qué te
a qué se
a qué lo
a qué la
con qué me
con qué te
con qué se
con qué lo
con qué la
en qué me
en qué te
en qué se
en qué lo
por qué me
por qué te
por qué se
por qué lo
por qué la
por qué le
por qué nos
por qué os
por qué no
por qué es
por qué está
por qué ha
para qué me
para qué te
para qué se
qué es el
qué es la
qué es un
qué es una
qué son los
qué son las
cuál es el
cuál es la
cuál es un
cuál es una
cuáles son los
cuáles son las
dónde está el
dónde está la
dónde está un
dónde está una
dónde están los
dónde están las
si me lo
si me la
si te lo
si te la
si se lo
si se la
si nos lo
si os lo
si no me
si no te
si no se
si no lo
si no la
si no le
si no nos
si no os
cuando me lo
cuando me la
cuando te lo
cuando te la
cuando se lo
cuando se la
cuando no me
cuando no te
cuando no se
cuando no lo
cuando no la
porque me lo
porque me la
porque te lo
porque te la
porque se lo
porque se la
porque no me
porque no te
porque no se
porque no lo
porque no la
porque no le
aunque me lo
aunque te lo
aunque se lo
aunque no me
aunque no te
aunque no se
aunque no lo
mientras me lo
mientras te lo
mientras se lo
mientras no me
mientras no te
mientras no se
como me lo
como te lo
como se lo
como no me
como no te
como no se
es que el
es que la
es que los
es que las
es que un
es que una
es que unos
es que unas
es que me
es que te
es que se
es que lo
es que la
es que le
es que nos
es que os
todo lo que
de lo que me
de lo que te
de lo que se
de lo que lo
de lo que la
de lo que le
de lo que nos
de lo que os
de lo que no
de lo que es
de lo que está
de lo que hay
a lo que me
a lo que te
a lo que se
a lo que lo
a lo que la
a lo que le
a lo que no
en lo que me
en lo que te
en lo que se
en lo que lo
en lo que la
en lo que le
en lo que no
en lo que es
en lo que está
con lo que me
con lo que te
con lo que se
con lo que lo
con lo que la
con lo que le
con lo que no
en el que me
en el que te
en el que se
en el que no
en la que me
en la que te
en la que se
en la que no
en los que se
en las que se
con el que me
con el que te
con el que se
con el que no
con la que me
con la que te
con la que se
con la que no
por el que me
por el que te
por el que se
por el que no
por la que me
por la que te
por la que se
por la que no
para el que me
para el que te
para el que se
para el que no
para la que me
para la que te
para la que se
para la que no
lo que me ha
lo que te ha
lo que se ha
lo que le ha
lo que nos ha
lo que me han
lo que te han
lo que se han
lo que no me
lo que no te
lo que no se
lo que no lo
lo que no la
que me lo ha
que me la ha
que te lo ha
que te la ha
que se lo ha
que se la ha
que nos lo ha
que nos la ha
que os lo ha
que os la ha
que me lo han
que te lo han
que se lo han
que no me lo
que no me la
que no te lo
que no te la
que no se lo
que no se la
si no me lo
si no me la
si no te lo
si no te la
si no se lo
si no se la
cuando no me lo
cuando no te lo
cuando no se lo
porque no me lo
porque no te lo
porque no se lo
aunque no me lo
aunque no te lo
aunque no se lo
mientras no me lo
mientras no te lo
mientras no se lo
qué es lo que
qué es lo de
cuál es el que
cuál es la que
cuáles son los que
cuáles son las que
por qué no me
por qué no te
por qué no se
por qué no lo
por qué no la
por qué me lo
por qué te lo
por qué se lo
dónde está el que
dónde está la que
dónde están los que
dónde están las que
es que no me
es que no te
es que no se
es que no lo
es que no la
es que me lo
es que me la
es que te lo
es que te la
es que se lo
es que se la
"""
}
