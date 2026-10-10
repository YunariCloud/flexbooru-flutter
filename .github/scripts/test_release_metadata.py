import unittest

from release_metadata import prepare_metadata


class ReleaseMetadataTests(unittest.TestCase):
    def test_regular_ci_cannot_publish(self):
        result = prepare_metadata({
            "GITHUB_EVENT_NAME": "pull_request", "GITHUB_RUN_NUMBER": "4",
            "INPUT_PUBLISH": "true",
        }, "version: 1.0.0+1\n")
        self.assertEqual(result["publish"], "false")
        self.assertEqual(result["build_number"], "5")

    def test_tag_sets_binary_version_and_prerelease(self):
        result = prepare_metadata({
            "GITHUB_EVENT_NAME": "push", "GITHUB_REF_TYPE": "tag",
            "GITHUB_REF_NAME": "v1.2.3-rc.1", "GITHUB_RUN_NUMBER": "8",
        }, "version: 1.0.0+1\n")
        self.assertEqual(result["version"], "1.2.3")
        self.assertEqual(result["prerelease"], "true")
        self.assertEqual(result["publish"], "true")

    def test_manual_publish_requires_tag_and_rejects_invalid_names(self):
        environment = {"GITHUB_EVENT_NAME": "workflow_dispatch",
                       "INPUT_PUBLISH": "true", "GITHUB_RUN_NUMBER": "1"}
        for tag in ["", "--help", "v1.0.0\nmalicious=output", "v1.0.0/other"]:
            with self.subTest(tag=tag), self.assertRaises(ValueError):
                prepare_metadata({**environment, "INPUT_TAG": tag}, "version: 1.0.0+1\n")


if __name__ == "__main__":
    unittest.main()
