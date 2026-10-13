import importlib.util
from html.parser import HTMLParser
from pathlib import Path
import unittest
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('discussion_export', ROOT / 'tools/export_discussion_pack.py')
m = importlib.util.module_from_spec(spec)
spec.loader.exec_module(m)


class TagCollector(HTMLParser):
    def __init__(self):
        super().__init__()
        self.tags = []
    def handle_starttag(self, tag, attrs):
        self.tags.append((tag, dict(attrs)))


class DiscussionPackTests(unittest.TestCase):
    def setUp(self):
        self.ballot_source = (ROOT / 'docs/design/ballot-round-1.md').read_text(encoding='utf-8')
        self.question_source = (ROOT / 'docs/design/questions.md').read_text(encoding='utf-8')
        self.ballots = m.ballot_questions(self.ballot_source)
        self.questions = m.question_rows(self.question_source)

    def test_ballot_has_eight_neutral_questions(self):
        self.assertEqual([b[0] for b in self.ballots], [f'Q{i:02}' for i in range(1, 9)])
        for _, _, options, _ in self.ballots:
            labels = [label for _, label in options]
            self.assertTrue(any('其他' in label for label in labels))
            self.assertTrue(any('暂不确定' in label for label in labels))
            self.assertEqual(len({letter for letter, _ in options}), len(options))

    def test_question_ids_are_stable_and_unique(self):
        self.assertEqual([q[0] for q in self.questions], [f'Q{i:02}' for i in range(1, 41)])
        with self.assertRaises(ValueError): m.question_rows(self.question_source.replace('| Q40 |', '| Q39 |'))
        with self.assertRaises(ValueError): m.ballot_questions('no ballot')

    def test_svg_is_static_and_bounded(self):
        root = ET.fromstring(m.svg_source())
        self.assertEqual(root.attrib['viewBox'], '0 0 680 480')
        ns = {'s': 'http://www.w3.org/2000/svg'}
        self.assertEqual(len(root.findall('s:path', ns)), 6)
        self.assertEqual(len(root.findall('s:rect', ns)), 8)  # background, center, six branches
        self.assertFalse(root.findall('.//s:script', ns))
        self.assertFalse(root.findall('.//s:image', ns))
        self.assertFalse(any('href' in key for node in root.iter() for key in node.attrib))

    def test_offline_page_does_not_submit_track_or_preselect(self):
        page = m.offline_html(m.svg_source(), self.ballots, self.questions)
        parser = TagCollector()
        parser.feed(page)
        self.assertFalse(any(tag in ('script', 'iframe', 'form', 'link') for tag, _ in parser.tags))
        self.assertFalse(any('checked' in attrs for _, attrs in parser.tags))
        self.assertFalse(any(key in attrs for _, attrs in parser.tags for key in ('src', 'action')))
        controls = [(tag, a) for tag, a in parser.tags if tag == 'input' and a.get('type') in ('radio', 'checkbox')]
        self.assertEqual({a['name'] for _, a in controls}, {f'Q{i:02}' for i in range(1, 9)})
        for _, a in controls:
            self.assertEqual(a['type'], 'checkbox' if a['name'] in ('Q01', 'Q07') else 'radio')
        self.assertIn('不保存或上传任何答案', page)
        self.assertIn('首选 → 次选', page)
        self.assertIn('个人答案：尚未填写', page)
        self.assertIn('不要求集中填票或发回', page)
        self.assertIn('Q40', page)

    def test_share_sources_match_current_docs(self):
        self.assertEqual((ROOT / 'share/cun-discussion-map.svg').read_text(encoding='utf-8'), m.svg_source())
        self.assertEqual((ROOT / 'share/team-discussion.html').read_text(encoding='utf-8'), m.offline_html(m.svg_source(), self.ballots, self.questions))

    def test_personal_agent_kit_covers_all_questions_without_filling_answers(self):
        import re
        kit = (ROOT / 'docs/design/agent-discussion-kit.md').read_text(encoding='utf-8')
        sections = re.findall(r'^### (Q\d{2}) (.+?)\n(.*?)(?=^### |^## |\Z)', kit, re.M | re.S)
        self.assertEqual([s[0] for s in sections], [f'Q{i:02}' for i in range(1, 41)])
        for _, _, body in sections:
            self.assertIn('**候选**', body)
            self.assertIn('**取舍**', body)
            self.assertIn('**建议**', body)
        self.assertIn('不替我回答', kit)
        self.assertIn('不要求集中填票', kit)
        self.assertIn('一次最多问2–3个问题', kit)

    def test_metadata_is_escaped_in_offline_page(self):
        ballots = [('Q01', '<script>bad</script>', [('A', '<img src=x onerror=bad>')], ['<iframe>'])]
        page = m.offline_html(m.svg_source(), ballots, [['Q01', '<script>', 'A & B', 'test']])
        self.assertNotIn('<script>bad</script>', page)
        self.assertNotIn('<img src=x', page)
        self.assertIn('&lt;script&gt;', page)
        self.assertIn('A &amp; B', page)


if __name__ == '__main__': unittest.main()
