#!/bin/bash
#SBATCH --job-name=pinfer-raft   # create a short name for your job
#SBATCH --nodes=1                # node count
#SBATCH --ntasks=1               # total number of tasks across all nodes
#SBATCH --cpus-per-task=64        # cpu-cores per task (>1 if multi-threaded tasks)
#SBATCH --mem-per-cpu=4G         # memory per cpu-core (4G is default)
#SBATCH --time=02:00:00          # total run time limit (HH:MM:SS)
#SBATCH --mail-type=end          # send email when job ends
#SBATCH --mail-user=dh7120@princeton.edu
source /scratch/network/dh7120/osdi24/activate
export PINFER_NUM_CORES=$SLURM_CPUS_PER_TASK
cd benchmarks/Raft
dotnet /scratch/network/dh7120/osdi24/P/Bld/Drops/Release/Binaries/net8.0/p.dll infer --action run --hint SingleLeader