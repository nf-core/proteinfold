"""Unit tests for the ModelCIF SI table formatter."""

import importlib.util
import io
import pathlib
import sys
import tempfile
import types
import unittest


SCRIPT = pathlib.Path(__file__).parents[1] / "bin" / "modelcif_metadata_to_table.py"


def _load_script():
    modelcif = types.ModuleType("modelcif")
    reader = types.ModuleType("modelcif.reader")
    reader.read = lambda handle: []
    modelcif.reader = reader
    sys.modules["modelcif"] = modelcif
    sys.modules["modelcif.reader"] = reader
    spec = importlib.util.spec_from_file_location("metadata_table", SCRIPT)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


class Object:
    def __init__(self, **attributes):
        self.__dict__.update(attributes)


class Group(list):
    def __init__(self, models, **attributes):
        super().__init__(models)
        self.__dict__.update(attributes)


class MetadataTableTest(unittest.TestCase):
    def test_rows_include_si_properties(self):
        formatter = _load_script()
        entity = Object(sequence="ACD", description="target", references=[])
        metrics = [
            Object(metric_name="pTM", mode="global", value=0.91),
            Object(metric_name="pLDDT", mode="local", value=80.0),
            Object(metric_name="pLDDT", mode="local", value=90.0),
        ]
        chain_a = Object(id="A")
        chain_b = Object(id="B")
        metrics.append(Object(
            metric_name="pTM per chain", mode="per-feature", value=0.84,
            feature=Object(asym_units=[chain_a]),
        ))
        metrics.append(Object(
            metric_name="ipTM per chain pair", mode="per-feature-pair", value=0.79,
            feature1=Object(asym_units=[chain_a]),
            feature2=Object(asym_units=[chain_b]),
        ))
        model = Object(name="rank_0", model_type="ab initio", qa_metrics=metrics)
        second_model = Object(
            name="rank_1", model_type="ab initio",
            qa_metrics=[Object(metric_name="pTM", mode="global", value=0.73)],
        )
        software = Object(
            name="Predictor", version="1.2", classification="modeling",
            parameters=[Object(name="seed", value=42)],
        )
        step = Object(name="Modeling", details="Prediction", software=software)
        system = Object(
            title="Example prediction", entities=[entity],
            asym_units=[Object(id="A", details="chain A", entity=entity)],
            software=[software], protocols=[Object(steps=[step])],
            model_groups=[Group([model, second_model], name="All models")], repositories=[],
            templates=[], software_groups=[],
        )

        rows = list(formatter._rows(system))
        self.assertIn(("Target composition", "Entity 1", "target; 3 residues", "Chain(s): A"), rows)
        self.assertIn(("Prediction method", "Settings for Predictor (version 1.2)", "seed=42", ""), rows)
        self.assertIn(("Models and confidence", "rank_0: pTM", "0.91", "ModelCIF metric mode: global"), rows)
        self.assertIn((
            "Models and confidence", "rank_0: Residue pLDDT",
            "median 85; mean 85; range 80–90",
            "Summary of 2 local values; individual values remain in the ModelCIF",
        ), rows)
        self.assertIn((
            "Models and confidence", "rank_0: Chain A pTM", "0.84",
            "ModelCIF metric mode: per-feature",
        ), rows)
        self.assertIn((
            "Models and confidence", "rank_0: Chains A–B ipTM", "0.79",
            "ModelCIF metric mode: per-feature-pair",
        ), rows)
        self.assertIn((
            "Models and confidence", "rank_1: pTM", "0.73",
            "ModelCIF metric mode: global",
        ), rows)

    def test_tabular_output_has_si_header(self):
        formatter = _load_script()
        system = Object(
            id="example", title="Example", entities=[], asym_units=[], software=[],
            protocols=[], model_groups=[], repositories=[], templates=[],
            software_groups=[],
        )
        formatter.modelcif.reader.read = lambda handle: [system]
        output = io.StringIO()
        with tempfile.NamedTemporaryFile(suffix=".mmcif") as modelcif_file:
            formatter.write_metadata(modelcif_file.name, output)
        self.assertEqual(output.getvalue().splitlines()[0],
                         "System\tSection\tItem\tResult\tReviewer note")

    def test_normalizes_decimal_integer_parameter(self):
        formatter = _load_script()
        content = """loop_
_ma_software_parameter.parameter_id
_ma_software_parameter.group_id
_ma_software_parameter.data_type
_ma_software_parameter.name
_ma_software_parameter.value
1 1 integer num_recycles 10.0
#
"""
        repaired, count = formatter._normalize_integer_parameters(content)
        self.assertEqual(count, 1)
        self.assertIn("1 1 integer num_recycles 10", repaired)


if __name__ == "__main__":
    unittest.main()
