# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#  http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

info() {
    [ -t 1 ] && [ -n "$TERM" ] \
        && echo "$(tput setaf 2)[$LOG_NAME]$(tput sgr0) $*" \
        || echo "[$LOG_NAME] $*"
}

err() {
	[ -t 2 ] && [ -n "$TERM" ] \
		&& echo -e "$(tput setaf 1)[$LOG_NAME]$(tput sgr0) $*" 1>&2 \
		|| echo -e "[$LOG_NAME] $*" 1>&2
}

die() {
	err "$@"
	exit 1
}

ok_or_die() {
	if [ $? -ne 0 ]; then
		die $1
	fi
}
