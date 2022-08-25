# Update git
# cd /home/luisasantus/Desktop/crg_cluster/projects/proteinfold/alphafold_split
# git add .
# git commit -m"fix"
# git push

# # Prep docker and singularity
# cd /home/luisasantus/Desktop/crg_cluster/projects/proteinfold/proteinfold/containers
# docker build -t luisas/af2_msa:$1 - < Dockerfile_AF2_MSA
# docker push luisas/af2_msa:$1
# singularity build luisas-af2_msa-$1.img docker://luisas/af2_msa:$1
# mv luisas-af2_msa-$1.img /home/luisasantus/Desktop/crg_cluster/containers/


cd /home/luisasantus/Desktop/crg_cluster/projects/proteinfold/proteinfold/containers
docker build -t luisas/af2_split:$1 - < Dockerfile_AF2_split
docker push luisas/af2_split:$1
singularity build luisas-af2_split-$1.img docker://luisas/af2_split:$1
mv luisas-af2_split-$1.img /home/luisasantus/Desktop/crg_cluster/containers/
