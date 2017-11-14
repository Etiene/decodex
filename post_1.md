# Decodex Machine Learning  - Part I

## Project based learning: The Decodex Project

I decided I wanted to learn Machine Learning (ML) some time ago. And my way of learning things is making projects with the things I'm trying to learn. I also happen to have an obsession with the book Codex Seraphinianus.

By those who do not know it, Codex Seraphinianus is a book written by Luigi Serafini between 1976 and 1978. According to some, it is one of the weirdest books ever published. The author spoke publicly about it on rare occasions. It consists of some kind of encyclopedia of an alternate reality or different world, beautifully illustrated in surrealist images, written in more than one made-up alphabet in maybe an unknown language. Nobody knows if it is a language or if it even has any meaning at all. We can notice that the book is divided in chapters with sections that could be fauna, flora, tribes, tools etc. by the illustrations. Some have figured out the numbering system of the paging. Multiple linguists have tried to decipher it and failed, discovering maybe some interesting information or patterns. Many years later, Serafini himself said that there is no meaning to it, that he wanted to give readers the same feeling as a small child "reading" a book.

Well, he certainly succeeded in passing this feeling, but I still wonder if there isn't really any meaning at all. Who knows maybe there aren't NSFW jokes or communist propaganda hidden in it!?? C'mon, there must be at least some easter eggs. If there isn't at least one, I'd say wow, Serafini, WHAT A MISSED OPPORTUNITY. I was not 100% sure and I couldn't let this go. I spent countless hours searching, going in spirals of personal websites and blog posts of people attempting to decipher it.

I finally managed to get myself a printed copy of this book when I got an Amazon voucher for any book in a Hackathon (Hey Swiftkey, if you ever read this, thank you very much). It's one of my treasures and I love looking at it. One day I realized, woah, but I don't think anybody tried Machine Learning yet! Just to be clear, I had no idea what ML meant at that point, only a rough idea of some of the insane things it could do. And no, I do not have the pretense at all to think I will be successful in deciphering anything. But this was a great occasion to learn ML. Even on the most possible outcome that there isn't anything to it, it's still a fun exercise aligned with my obsession du jour.

# Devising a plan

The first part was informing myself on the themes. So what is machine learning after all? Which other techniques will I need to accomplish something with this project?

After some investigations I decided to break this project down into a set of different tasks:

 1 - Use Optical Character Recognition techniques to easily extract characters from scanned book pages
 2 - Have a Machine Learning (ML) model that is able to correctly classify single characters
 3 - Combine 1 and 2 to obtain data that represents the book's text
 4 - Use Natural Language Processing techniques to inquire about its meaning

Although this looks like a natural order to proceed with this project, we can also represent this
list in a Directed Acyclic Graph (DAG).

<image>
1--3--4
2--|

With this representation we can see step 1 and 2 do not have pre-requisites and are both required
for step 3. So I could start with either of them. Given my main purpose is to learn Machine Learning,
I decided the best place for me to start was step 2.

# Machine Learning Learning


<xkcd picture>

Alright, so what does it mean, to have an ML model that is able to correctly classify single character?
And how did I come to the conclusion that this was what I needed? To be frank, I wasn't sure. But I was prepared
to research more on the subject and amend my proposal if necessary be.

This step, itself, can be represented in its own DAG.

<image>                 - decide approach related to my problem
<Study machine learning - Pick a tool and install it-  implement approach following tool's docs, tutorials and examples
                        - Prepare a dataset with samples of characters>

## Study machine learning
I started an online course, twice, did not finish. Read buzz blog posts coming on hackernews now and then. Started following what was going on with open-source projects in this area within the community I was closer with, which is Lua (this is when I discovered Torch, a scientific computing framework I'll get into more details later on). Started talking about ML with friends and even with strangers when drunk in pubs! Finally I came across this material which was great for me: https://medium.com/@ageitgey/machine-learning-is-fun-80ea3ec3c471

Machine Learning is a field closely tied to Statistics and Artificial Intelligence. Many learning problems are formulated as minimization of some loss function on a training set of examples


https://pt.wikipedia.org/wiki/Codex_Seraphinianus

https://en.wikipedia.org/wiki/Optical_character_recognition

https://www.abebooks.com/books/rarebooks/serafini-fantasy-art-weird/Codex-Seraphinianus.shtml

https://github.com/torch/torch7

http://codexseraphinianus.weebly.com/glyphs.html

http://www.paleoaliens.com/event/seraphinianus/codex/

https://medium.com/@ageitgey/machine-learning-is-fun-80ea3ec3c471
