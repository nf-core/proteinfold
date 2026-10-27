# Copyright 2021 DeepMind Technologies Limited
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

import pathlib
import pickle
import random
import sys

from absl import app
from absl import flags
from absl import logging
from alphafold.common import residue_constants
from alphafold.data import parsers
from alphafold.model import config
from alphafold.model import data
from alphafold.model import model
from alphafold.relax import relax
import numpy as np
import run_alphafold

FLAGS = flags.FLAGS
flags.DEFINE_string('msa_path', None, 'Path to features.pkl from run_msa.py.')
flags.DEFINE_boolean('run_relax', True, 'Relax predictions (legacy split CLI).')


class FeatureLoader:
  def __init__(self, features):
    self.features = features

  def process(self, input_fasta_path, msa_output_dir):
    del input_fasta_path, msa_output_dir
    return self.features


def load_features(msa_path, fasta_path, multimer):
  with open(msa_path, 'rb') as f:
    features = pickle.load(f)
  with open(fasta_path) as f:
    sequences, _ = parsers.parse_fasta(f.read())
  if not sequences:
    raise ValueError(f'No sequences found in {fasta_path}.')
  if multimer != ('asym_id' in features):
    raise ValueError('Feature pickle and --model_preset disagree about multimer mode.')
  aatype = np.asarray(features['aatype'])
  if aatype.ndim != (1 if multimer else 2):
    raise ValueError('Feature pickle has an unexpected aatype shape for this preset.')
  expected = np.array([
      residue_constants.restype_order_with_x.get(aa, 20)
      for aa in ''.join(sequences)
  ])
  observed = aatype if multimer else np.argmax(aatype, axis=-1)
  if not np.array_equal(observed, expected):
    raise ValueError(
        f'Features in {msa_path} do not match the sequence in {fasta_path}. '
        'Regenerate features for this FASTA and model preset.'
    )
  for key in ('msa', 'residue_index'):
    if key not in features:
      raise ValueError(f'Feature pickle is missing required key: {key}')
  return features


def main(argv):
  if len(argv) > 1:
    raise app.UsageError('Too many command-line arguments.')
  if len(FLAGS.fasta_paths) != 1:
    raise ValueError('run_predict.py requires exactly one FASTA per --msa_path.')
  fasta_path = FLAGS.fasta_paths[0]
  fasta_name = pathlib.Path(fasta_path).stem
  run_multimer_system = FLAGS.model_preset == 'multimer'
  features = load_features(FLAGS.msa_path, fasta_path, run_multimer_system)
  num_ensemble = 8 if FLAGS.model_preset == 'monomer_casp14' else 1
  num_predictions_per_model = (
      FLAGS.num_multimer_predictions_per_model if run_multimer_system else 1
  )

  model_runners = {}
  for model_name in config.MODEL_PRESETS[FLAGS.model_preset]:
    model_config = config.model_config(model_name)
    if run_multimer_system:
      model_config.model.num_ensemble_eval = num_ensemble
    else:
      model_config.data.eval.num_ensemble = num_ensemble
    model_params = data.get_model_haiku_params(
        model_name=model_name, data_dir=FLAGS.data_dir
    )
    model_runner = model.RunModel(model_config, model_params)
    for i in range(num_predictions_per_model):
      model_runners[f'{model_name}_pred_{i}'] = model_runner

  if (FLAGS['run_relax'].present and FLAGS['models_to_relax'].present and
      (not FLAGS.run_relax) !=
      (FLAGS.models_to_relax == run_alphafold.ModelsToRelax.NONE)):
    raise ValueError('--run_relax and --models_to_relax disagree.')
  models_to_relax = (
      run_alphafold.ModelsToRelax.NONE if not FLAGS.run_relax else
      FLAGS.models_to_relax if FLAGS['models_to_relax'].present else
      run_alphafold.ModelsToRelax.ALL
  )
  amber_relaxer = None
  if models_to_relax != run_alphafold.ModelsToRelax.NONE:
    if FLAGS.use_gpu_relax is None:
      logging.warning('No --use_gpu_relax specified; relaxation will use CPU.')
    amber_relaxer = relax.AmberRelaxation(
        max_iterations=run_alphafold.RELAX_MAX_ITERATIONS,
        tolerance=run_alphafold.RELAX_ENERGY_TOLERANCE,
        stiffness=run_alphafold.RELAX_STIFFNESS,
        exclude_residues=run_alphafold.RELAX_EXCLUDE_RESIDUES,
        max_outer_iterations=run_alphafold.RELAX_MAX_OUTER_ITERATIONS,
        use_gpu=FLAGS.use_gpu_relax,
    )

  random_seed = FLAGS.random_seed
  if random_seed is None:
    random_seed = random.randrange(sys.maxsize // len(model_runners))
  logging.info('Using random seed %d for prediction', random_seed)
  run_alphafold.predict_structure(
      fasta_path=fasta_path,
      fasta_name=fasta_name,
      output_dir_base=FLAGS.output_dir,
      data_pipeline=FeatureLoader(features),
      model_runners=model_runners,
      amber_relaxer=amber_relaxer,
      benchmark=FLAGS.benchmark,
      random_seed=random_seed,
      models_to_relax=models_to_relax,
      model_type='Multimer' if run_multimer_system else 'Monomer',
  )


if __name__ == '__main__':
  flags.mark_flags_as_required([
      'fasta_paths', 'output_dir', 'data_dir', 'msa_path'
  ])
  app.run(main)
