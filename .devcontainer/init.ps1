# Install pre-commit
pip install pre-commit
pre-commit install --install-hooks --overwrite

# Install powershell modules
Install-Module -Name Pester -Force
Install-Module -Name BCContainerHelper -Force