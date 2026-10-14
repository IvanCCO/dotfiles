import pathlib, unittest, io, types
from unittest.mock import patch

source = pathlib.Path(__file__).parents[1] / 'Sources/SSHMonitor/collector.py'
namespace = {}
exec(source.read_text().split("system = 'Linux'")[0], namespace)

class CollectorTests(unittest.TestCase):
    def test_swap_separates_disk_from_zram(self):
        sample = 'Filename Type Size Used Priority\n/dev/zram0 partition 8388608 4194304 100\n/swap-nvme/swapfile file 16777216 1048576 -2\n'
        with patch('builtins.open', return_value=io.StringIO(sample)):
            self.assertEqual(namespace['swap_usage'](), dict(swapUsed=1, swapTotal=16, zramUsed=4, zramTotal=8))

    def test_swap_without_devices(self):
        with patch('builtins.open', return_value=io.StringIO('Filename Type Size Used Priority\n')):
            self.assertEqual(namespace['swap_usage'](), dict(swapUsed=0, swapTotal=0, zramUsed=0, zramTotal=0))

    def test_cpu_excludes_guest_counters_and_includes_iowait(self):
        with patch('builtins.open', return_value=io.StringIO('cpu 10 2 8 50 5 3 2 1 100 200\n')):
            self.assertEqual(namespace['read_cpu'](), (81, 55))

    def test_process_name_with_parentheses_and_transient_exit(self):
        fields = ['S'] + ['0'] * 21
        fields[11], fields[12], fields[19], fields[21] = '40', '10', '123', '5'
        stat = '42 (worker (thread)) ' + ' '.join(fields)
        def read(path):
            if '43' in path: raise FileNotFoundError()
            return io.StringIO(stat)
        with patch('glob.glob', return_value=['/proc/42', '/proc/43']), patch('builtins.open', side_effect=read), patch('os.stat', return_value=types.SimpleNamespace(st_uid=1000)), patch('pwd.getpwuid', return_value=types.SimpleNamespace(pw_name='ivan')), patch('os.sysconf', return_value=4096):
            self.assertEqual(namespace['processes'](), {42: (50, 20480, 'worker (thread)', 'ivan', '123')})

    def test_gpu_available_and_unavailable(self):
        with patch('subprocess.check_output', return_value=b'NVIDIA GeForce GTX 1050 Ti, 42, 100, 4096, 55\n'):
            self.assertEqual(namespace['gpu']()['utilization'], 42)
        with patch('subprocess.check_output', side_effect=FileNotFoundError()):
            self.assertIsNone(namespace['gpu']())

if __name__ == '__main__': unittest.main()
