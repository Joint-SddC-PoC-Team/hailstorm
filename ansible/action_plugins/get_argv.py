from ansible.plugins.action import ActionBase
import sys

class ActionModule(ActionBase):

    TRANSFERS_FILES = False

    def run(self, tmp=None, task_vars=None):
        return { 'changed': False, 'ansible_facts': { 'argv': ["'%s'" % arg for arg in sys.argv] + ["-e is_install_host=yes"] } }
